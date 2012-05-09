import os
import logging
import sys
from simperium import optfunc
from simperium import core

def listener():
    simperium = core.Api('SIMPERIUM_APP_ID', 'SIMPERIUM_API_KEY')

    # persist the last known change version (cv) in Simperium...
    cv = None
    index = simperium.user.get()

    user_data = simperium.user.get()
    if user_data and 'cv' in user_data:
        cv = user_data['cv']

    while True:
        changes = simperium.player.all(cv, data=True)

        for change in changes:
            print >> sys.stderr, str(change) + '\n---'

            # store the change version so this service can pick up where it
            # left off
            cv = change['cv']
            simperium.user.post({'cv': cv})

            px = change['d']['tileX']
            py = change['d']['tileY']
            if px == 6 and py == 5:
                print >> sys.stderr, 'DIED!'
                simperium.player.set(change['id'],
                    {'tileX':2, 'tileY':2,'destinationX':2, 'destinationY':2})

print "listening..."
listener()