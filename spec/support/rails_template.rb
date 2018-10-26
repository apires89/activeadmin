# Rails template to build the sample app for specs

create_file 'app/assets/stylesheets/some-random-css.css'
create_file 'app/assets/javascripts/some-random-js.js'
create_file 'app/assets/images/a/favicon.ico'

belongs_to_optional_flag = if Rails::VERSION::MAJOR < 5
                             "required: false"
                           else
                             "optional: true"
                           end

generate :model, 'post title:string body:text published_date:date author_id:integer ' +
  'position:integer custom_category_id:integer starred:boolean foo_id:integer'

create_file 'app/models/post.rb', <<-RUBY.strip_heredoc, force: true
  class Post < ActiveRecord::Base
    belongs_to :category, foreign_key: :custom_category_id, #{belongs_to_optional_flag}
    belongs_to :author, class_name: 'User', #{belongs_to_optional_flag}
    has_many :taggings
    accepts_nested_attributes_for :author
    accepts_nested_attributes_for :taggings, allow_destroy: true

    ransacker :custom_title_searcher do |parent|
      parent.table[:title]
    end

    ransacker :custom_created_at_searcher do |parent|
      parent.table[:created_at]
    end

    ransacker :custom_searcher_numeric, type: :numeric do
      # nothing to see here
    end

  end
RUBY
copy_file File.expand_path('../templates/post_decorator.rb', __FILE__), 'app/models/post_decorator.rb'

generate :model, 'blog/post title:string body:text published_date:date author_id:integer ' +
  'position:integer custom_category_id:integer starred:boolean foo_id:integer'
create_file 'app/models/blog/post.rb', <<-RUBY.strip_heredoc, force: true
  class Blog::Post < ActiveRecord::Base
    belongs_to :category, foreign_key: :custom_category_id
    belongs_to :author, class_name: 'User'
    has_many :taggings
    accepts_nested_attributes_for :author
    accepts_nested_attributes_for :taggings, allow_destroy: true

  end
RUBY

generate :model, 'profile user_id:integer bio:text'

generate :model, 'user type:string first_name:string last_name:string username:string age:integer'
create_file 'app/models/user.rb', <<-RUBY.strip_heredoc, force: true
  class User < ActiveRecord::Base
    class VIP < self
    end
    has_many :posts, foreign_key: 'author_id'
    has_one :profile
    accepts_nested_attributes_for :profile, allow_destroy: true
    accepts_nested_attributes_for :posts, allow_destroy: true

    ransacker :age_in_five_years, type: :numeric, formatter: proc { |v| v.to_i - 5 } do |parent|
      parent.table[:age]
    end

    def display_name
      "\#{first_name} \#{last_name}"
    end
  end
RUBY

create_file 'app/models/profile.rb', <<-RUBY.strip_heredoc, force: true
  class Profile < ActiveRecord::Base
    belongs_to :user
  end
RUBY

generate :model, 'publisher --migration=false --parent=User'

generate :model, 'category name:string description:text'
create_file 'app/models/category.rb', <<-RUBY.strip_heredoc, force: true
  class Category < ActiveRecord::Base
    has_many :posts, foreign_key: :custom_category_id
    has_many :authors, through: :posts
    accepts_nested_attributes_for :posts
  end
RUBY

generate :model, 'store name:string'

generate :model, 'tag name:string'
create_file 'app/models/tag.rb', <<-RUBY.strip_heredoc, force: true
  class Tag < ActiveRecord::Base
  end
RUBY

generate :model, 'tagging post_id:integer tag_id:integer position:integer'
create_file 'app/models/tagging.rb', <<-RUBY.strip_heredoc, force: true
  class Tagging < ActiveRecord::Base
    belongs_to :post, #{belongs_to_optional_flag}
    belongs_to :tag, #{belongs_to_optional_flag}

    delegate :name, to: :tag, prefix: true
  end
RUBY

gsub_file 'config/environments/test.rb', /  config.cache_classes = true/, <<-RUBY

  config.cache_classes = !ENV['CLASS_RELOADING']
  config.action_mailer.default_url_options = {host: 'example.com'}
  config.assets.precompile += %w( some-random-css.css some-random-js.js a/favicon.ico )

  config.active_record.maintain_test_schema = false

RUBY

# Setup Active Admin
generate 'active_admin:install'

# Force strong parameters to raise exceptions
inject_into_file 'config/application.rb', after: 'class Application < Rails::Application' do
  "\n    config.action_controller.action_on_unpermitted_parameters = :raise\n"
end

# Add some translations
append_file 'config/locales/en.yml', File.read(File.expand_path('../templates/en.yml', __FILE__))

# Add predefined admin resources
directory File.expand_path('../templates/admin', __FILE__), 'app/admin'

# Add predefined policies
directory File.expand_path('../templates/policies', __FILE__), 'app/policies'

if ENV['RAILS_ENV'] != 'test'
  inject_into_file 'config/routes.rb', "\n  root to: redirect('admin')", after: /.*routes.draw do/
end

rake "db:drop db:create db:migrate", env: ENV['RAILS_ENV']

if ENV['RAILS_ENV'] == 'test'
  inject_into_file 'config/database.yml', "<%= ENV['TEST_ENV_NUMBER'] %>", after: 'test.sqlite3'

  rake "parallel:drop parallel:create parallel:load_schema", env: ENV['RAILS_ENV']
end
