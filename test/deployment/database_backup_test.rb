require "test_helper"
require "open3"
require "tmpdir"

# §12: "a documented, **actually-tested** restore procedure. A backup nobody has
# restored is not a backup."
#
# This is that test. It runs the two scripts a server actually runs — not a Ruby
# reimplementation of them — against a real SQLite database with real rows in it,
# and then reads the rows back. The parts it cannot exercise are the server's:
# cron firing, and the copy reaching off-box storage. Everything between the live
# database and the restored one is here.
class DatabaseBackupTest < ActiveSupport::TestCase
  BACKUP  = Rails.root.join("script/backup_database").to_s
  RESTORE = Rails.root.join("script/restore_database").to_s

  setup do
    @dir = Dir.mktmpdir("backup-test")
    @database = File.join(@dir, "production.sqlite3")
    @backups = File.join(@dir, "backups")

    # WAL, because that is how Rails 8 opens SQLite and it is the mode the whole
    # restore hazard comes from.
    sqlite @database, "PRAGMA journal_mode=WAL;",
                      "CREATE TABLE projects (id INTEGER PRIMARY KEY, name TEXT);",
                      "INSERT INTO projects (name) VALUES ('Apollo'), ('Gemini');"
  end

  teardown { FileUtils.remove_entry(@dir) }

  test "a backup is a readable database with the rows that were live" do
    script! BACKUP, @database, @backups

    assert_equal [ "Apollo", "Gemini" ], project_names(only_backup)
  end

  test "the backup is verified before it is kept, not after it is needed" do
    out = script! BACKUP, @database, @backups

    assert_match(/integrity/i, out, "the script does not say it checked the copy")
    assert_equal "ok", sqlite(only_backup, "PRAGMA integrity_check;").strip
  end

  # A backup taken while the app is writing is the only kind this app ever takes:
  # the server is not stopped for it. sqlite3's .backup takes the same locks the
  # app does, which is why the backup runs against the file directly rather than
  # copying it — `cp` of a database mid-write produces a file that passes no
  # check at all.
  test "a backup taken while another connection is writing is still consistent" do
    writer = IO.popen([ "sqlite3", @database ], "w")
    writer.puts "BEGIN; INSERT INTO projects (name) VALUES ('Mercury');"

    script! BACKUP, @database, @backups
    writer.puts "COMMIT;"
    writer.close

    # The uncommitted row must not be in the copy, and the copy must be sound.
    assert_equal "ok", sqlite(only_backup, "PRAGMA integrity_check;").strip
    assert_equal [ "Apollo", "Gemini" ], project_names(only_backup)
  end

  # Off-box storage is not free and neither is the disk the copies land on first,
  # so the schedule has to prune itself. Written against a fixed set of older
  # files rather than by taking several backups in a row: the timestamps are to
  # the second and a loop is faster than that.
  test "pruning keeps the newest backups and deletes the rest" do
    FileUtils.mkdir_p(@backups)
    older = %w[20200101T000000Z 20200102T000000Z 20200103T000000Z].map do |stamp|
      File.join(@backups, "production-#{stamp}.sqlite3").tap { |path| File.write(path, "") }
    end

    script! BACKUP, @database, @backups, "KEEP" => "2"

    kept = Dir[File.join(@backups, "*.sqlite3")].sort
    assert_equal 2, kept.size, "KEEP=2 left #{kept.size} backups"
    assert_includes kept, older.last, "the newest of the old copies was deleted"
    assert_not_includes kept, older.first
  end

  test "a restore brings back the rows that were lost" do
    script! BACKUP, @database, @backups
    backup = only_backup

    sqlite @database, "DELETE FROM projects;"
    assert_empty project_names(@database)

    script! RESTORE, "--yes", backup, @database

    assert_equal [ "Apollo", "Gemini" ], project_names(@database)
  end

  # The restore bug that eats a restore. SQLite replays a write-ahead log it
  # finds beside a database, so a restored file with the *old* -wal still next to
  # it is read as the old database — the restore appears to run, reports success,
  # and changes nothing.
  test "a restore clears the write-ahead log left by the database it replaced" do
    script! BACKUP, @database, @backups
    backup = only_backup

    sqlite @database, "PRAGMA journal_mode=WAL;", "INSERT INTO projects (name) VALUES ('Skylab');"
    File.write("#{@database}-wal", "stale") unless File.exist?("#{@database}-wal")

    script! RESTORE, "--yes", backup, @database

    assert_not File.exist?("#{@database}-wal"), "a stale -wal beside the restored file is the old database"
    assert_not File.exist?("#{@database}-shm")
    assert_equal [ "Apollo", "Gemini" ], project_names(@database)
  end

  # Restoring the wrong backup must not be the end of the story. The database
  # being replaced is moved aside, not deleted.
  test "a restore keeps the database it replaced" do
    script! BACKUP, @database, @backups
    sqlite @database, "INSERT INTO projects (name) VALUES ('Skylab');"

    script! RESTORE, "--yes", only_backup, @database

    replaced = Dir["#{@database}.replaced-*"]
    assert_equal 1, replaced.size, "the replaced database was deleted rather than kept"
    assert_includes project_names(replaced.first), "Skylab"
  end

  test "a restore refuses a corrupt backup rather than installing it" do
    script! BACKUP, @database, @backups
    backup = only_backup
    File.write(backup, "this is not a database", mode: "r+")

    _out, err, status = script RESTORE, "--yes", backup, @database

    assert_not_predicate status, :success?
    assert_match(/integrity|not a database/i, err + _out)
    assert_equal [ "Apollo", "Gemini" ], project_names(@database), "the live database was touched anyway"
  end

  # Without --yes it must not be possible to lose a database by pasting a
  # half-remembered command. There is no terminal here to answer the prompt.
  test "a restore without --yes does nothing" do
    script! BACKUP, @database, @backups
    sqlite @database, "DELETE FROM projects;"

    _out, _err, status = script RESTORE, only_backup, @database

    assert_not_predicate status, :success?
    assert_empty project_names(@database), "it restored without being told to"
  end

  private
    def sqlite(database, *statements)
      out, err, status = Open3.capture3("sqlite3", database, statements.join(" "))
      raise "sqlite3 failed: #{err}" unless status.success?
      out
    end

    def project_names(database)
      sqlite(database, "SELECT name FROM projects ORDER BY name;").split("\n")
    end

    def only_backup
      backups = Dir[File.join(@backups, "*.sqlite3")]
      assert_equal 1, backups.size, "expected exactly one backup, found #{backups.inspect}"
      backups.first
    end

    def script(*command)
      env = command.last.is_a?(Hash) ? command.pop : {}
      Open3.capture3(env, *command)
    end

    def script!(*command)
      out, err, status = script(*command)
      assert_predicate status, :success?, "#{command.first} failed:\n#{out}\n#{err}"
      out
    end
end
