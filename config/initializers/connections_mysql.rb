=begin
unless Rails.env.to_s == 'test'
  module ActiveRecord::ConnectionAdapters
    class Mysql2Adapter
      alias_method :execute_without_retry, :execute

    def execute(*args)
      execute_without_retry(*args)
      rescue Exception => e
        if e.message =~ /server has gone away/i
          warn "Server timed out, retrying"
          reconnect!
          retry
        else
          raise e
        end
      end
    end
  end
end
=end