Git Party
========================


Installation Instructions
------------------------

To get this project started with PostgreSQL, create a config/database.yml

    development:
      adapter: postgresql
      database: git_party_development
      pool: 5
      timeout: 5000

    test:
      adapter: postgresql
      database: git_party_test
      pool: 5
      timeout: 5000

    production:
      adapter: postgresql
      database: git_party_production
      pool: 5
      timeout: 5000

Then,
* bundle install
* bundle exec rake db:create:all
* bundle exec rake db:migrate
* bundle exec rake db:test:prepare

________________________
