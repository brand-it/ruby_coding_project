# frozen_string_literal: true

require 'sqlite3'

DB = SQLite3::Database.new 'biff.wellington.db'

enrollment = DB.execute("SELECT name FROM sqlite_master WHERE name='enrollment'")

if enrollment.empty?
  puts 'Creating Enrollment Table in biff.wellington database'
  DB.execute <<-SQL
    create table enrollment (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      host_identifier varchar(255),
      platform_type INT,
      host_details TEXT,
      node_key VARCHAR(255)
    );
  SQL
end
