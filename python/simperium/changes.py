
class ChangeProcessor(object):
    def process(self, change):
        if change['o'] == 'M':
            if 'sv' in change:
                for key in change['v']:
                    handler = getattr(self, 'on_change_%s' % key, None)
                    if handler:
                        handler(change['d'][key])
