import json
import sys

if __name__ == '__main__':
    infile = sys.argv[1]
    data = json.load(open(infile, 'rb'))
    expression = sys.argv[2]
    thing = eval(expression, {'x':data}, {})
    if type(thing) in (list, tuple):
        print '\n'.join([str(x) for x in thing])
    else:
        print thing

