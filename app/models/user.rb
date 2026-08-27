class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :memberships, dependent: :destroy
  has_many :projects, through: :memberships
  # Nullify, not destroy: removing a person must not delete the work they were
  # holding. It goes back to unassigned.
  has_many :assigned_stories, class_name: "Story", foreign_key: :assignee_id, dependent: :nullify, inverse_of: :assignee

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :name, presence: true
  validates :email_address, presence: true, uniqueness: true
end
