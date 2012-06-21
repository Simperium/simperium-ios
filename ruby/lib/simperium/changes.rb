module Simperium
    class ChangeProcessor
        def process(change)
            if change['o'] == 'M'
                if change.include?('sv')
                    change['v'].each do |key|
                        handler = self.send('on_change_#{key}')
                        if handler
                            handler(change['d'][key])
                        end
                    end
                end
            end
        end
    end
end