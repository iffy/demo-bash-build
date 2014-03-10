import re
import sys
import json
import os

from twisted.python import usage

r_whole_block = re.compile(r'''
    (<!--\s*group\s*.*?\s*-->
    .*?
    <!--\s*endgroup\s*-->)
    ''', re.X | re.S | re.M | re.I)
r_block_parts = re.compile(r'''
    <!--\s*group\s*(.*?)\s*-->
    (.*?)
    <!--\s*endgroup\s*-->
    ''', re.X | re.S | re.M | re.I)


r_script = re.compile(r'''
    <script\s*.*?src=['"](.*?)['"].*?>\s*</script>
    ''', re.X | re.S | re.M | re.I)
r_css = re.compile(r'''
    <link.*?href=['"](.*?)['"].*?>
    ''', re.X | re.S | re.M | re.I)


def logstderr(text):
    sys.stderr.write(str(text) + '\n')
    sys.stderr.flush()

def readGroup(options, source_files, filename, log=logstderr):
    group = {
        'options': options,
        'filename': filename,
        'absolute_filename': os.path.abspath(filename),
    }
    # determine type
    types = [
        ('script', r_script, '<script src="%(output)s"></script>'),
        ('css', r_css, '<link href="%(output)s" rel="stylesheet">'),
    ]
    for name,regex,html in types:
        m = regex.findall(source_files)
        if m:
            group['type'] = name
            group['inputs'] = m
            group['html'] = html % options
            break
    if 'type' not in group:
        raise TypeError("Could not determine type of files in block: %s" % (
                        source_files,))
    return group


def processFile(filename, outstream, log=logstderr):
    groups = []
    fh = open(filename, 'rb')
    chunks = r_whole_block.split(fh.read())
    for chunk in chunks:
        m = r_block_parts.search(chunk)
        if m:
            # it's a group
            options, source_files = m.groups()
            options = json.loads(options)
            group = readGroup(options, source_files, filename)
            groups.append(group)
            outstream.write(group['html'])
        else:
            # it's not a group
            outstream.write(chunk)
    return groups



class Options(usage.Options):

    optParameters = [
        ("groups-file", "g", "groups.json", "File to put group information in")
    ]

    def parseArgs(self, input_file):
        self['input-file'] = input_file


if __name__ == '__main__':
    options = Options()
    options.parseOptions()
    group_fh = open(options['groups-file'], 'wb')
    groups = processFile(options['input-file'], sys.stdout)
    group_fh.write(json.dumps(groups, indent=2))
