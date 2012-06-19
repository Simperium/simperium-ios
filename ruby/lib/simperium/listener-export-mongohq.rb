#!/usr/bin/env ruby
require 'rubygems'
require File.join(File.dirname(__FILE__), '../simperium')
require 'uri'
require 'mongo'
require 'optparse'

MONGHQ_URL = ENV['MONGHQ_URL']

uri = URI.parse(MONGHQ_URL)
conn = Mongo::Connection.from_uri(MONGHQ_URL)
$db = conn.db(uri.path.gsub(/^\//, ''))

def main(appname, admin_key, bucket)
    _bucket = Bucket.new(appname, admin_key, bucket)
    
    begin
        cv = $db['__meta__'].find_one
        cv = cv['cv']
    rescue StandardError => e
        cv = nil     
    end

    begin
        while true do
            changes = _bucket.all(:cv => cv, :data=>true)
            for change in changes
                data = change['d']
                # update mongo with the latest version of the data
                if data
                    data['_id'] = change['id']
                    # puts data
                    $db[bucket].save(data)
                else
                    $db[bucket].remove({'_id' => change['id']})
                end
                # persist the cv to mongo, so changes don't need to be
                # re-processed after restart
                $db['__meta__'].save({'_id' => 'cv', 'cv' => change['cv']})
                cv = change['cv']
            end
        end
    rescue StandardError => e
        raise StandardError.new('Mirroring failed')
    end
end

main(ARGV[0], ARGV[1], ARGV[2])