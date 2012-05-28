require File.join(File.dirname(__FILE__), '../simperium')

module Listener
    def self.mirror(appname, admin_key, bucket)
        bucket = Bucket.new(appname, admin_key, bucket)
        cv = nil
        begin
            while true do
                changes = bucket.all(:cv => cv, :data=>true)
                for change in changes
                    #TODO - add db mirroring here
                    puts change.to_str + '\n---'
                    cv = change['cv']
                end
            end
        rescue StandardError => e
            raise
        end
    end
end