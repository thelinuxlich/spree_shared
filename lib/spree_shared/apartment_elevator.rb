module Apartment
  module Elevators
    # Provides a rack based db switching solution based on subdomains
    # Assumes that database name should match subdomain
    class Subdomain

      def initialize(app)
        @app = app
      end

      def call(env)
        request = ActionDispatch::Request.new(env)

        Rails.logger.error "  Requested URL: #{request.url}, subdomain: #{request.subdomain}, host: #{request.host}"
        domain = subdomain(request)

        if domain
          #switch database
          begin

            ActiveRecord::Base.establish_connection

            result = ActiveRecord::Base.connection.execute("SELECT database from public.customers where ('#{domain}' = ANY(domains) OR '#{request.host}' = ANY(domains)) and status = true")

            if result.ntuples > 0
              database = result.getvalue(0, 0)
              Apartment::Tenant.switch database

              Rails.logger.error "  Using database '#{database}'"

              #set image location
              Spree::Image.change_paths database rescue p 'Image Class Was not loaded'
              Spree::Banner.change_paths database rescue p 'Banner Class Was not loaded'
              Spree::OptionValue.change_paths database rescue p ''
              Ckeditor.change_paths database rescue p ''

              #namespace cache keys
              ENV['RAILS_CACHE_ID'] = database

              #reset Mail settings
              Spree::Core::MailSettings.init
            else
              raise "Client is not active"
            end
          rescue Exception => e
            Rails.logger.error "  Stopped request due to: #{e.message}"

            #fallback
            ENV['RAILS_CACHE_ID'] = ""
            Apartment::Tenant.switch nil
            ActiveRecord::Base.establish_connection
            return ahh_no
          end

          #continue on to rails
          @app.call(env)
        else
          ahh_no
        end
      end

      def subdomain(request)
        request.subdomain.to_s.split('.').first
      end

      def ahh_no
        [200, {"Content-type" => "text/html"}, ["Ahh No."]]
      end

    end
  end
end

