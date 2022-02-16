from collections import namedtuple

DAY = 86400
WEEK = DAY * 7

# for debugging
def get_params(locals):
    if 'self' in locals:
        del locals['self']
        return locals
    else:
        return locals
