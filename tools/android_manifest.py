"""Read compiled AXML and change only the integer versionCode, preserving all other bytes."""
import struct

def inspect(data):
    strings = []
    elements = []
    version_offset = None
    pos = 8
    def length(offset, utf8):
        if utf8:
            n = data[offset]
            return (((n & 127) << 8) | data[offset+1], offset+2) if n & 128 else (n, offset+1)
        n = struct.unpack_from('<H', data, offset)[0]
        return (((n & 32767) << 16) | struct.unpack_from('<H', data, offset+2)[0], offset+4) if n & 32768 else (n, offset+2)
    while pos < len(data):
        kind, header, size = struct.unpack_from('<HHI', data, pos)
        if size < header or size == 0 or pos+size > len(data):
            raise ValueError('Invalid AXML chunk')
        if kind == 1:
            count, _, flags, start, _ = struct.unpack_from('<5I', data, pos+8)
            for i in range(count):
                offset = pos+start+struct.unpack_from('<I', data, pos+header+4*i)[0]
                if flags & 256:
                    _, offset = length(offset, True)
                    n, offset = length(offset, True)
                    strings.append(data[offset:offset+n].decode('utf-8'))
                else:
                    n, offset = length(offset, False)
                    strings.append(data[offset:offset+2*n].decode('utf-16le'))
        elif kind == 0x102:
            _, name, start, stride, count = struct.unpack_from('<IIHHH', data, pos+16)
            attrs = {}
            for i in range(count):
                offset = pos+16+start+i*stride
                _, attr, raw, _, _, datatype, value = struct.unpack_from('<IIIHBBI', data, offset)
                attrs[strings[attr]] = strings[raw] if raw != 0xffffffff else strings[value] if datatype == 3 else value
                if strings[name] == 'manifest' and strings[attr] == 'versionCode':
                    if datatype != 0x10 or raw != 0xffffffff:
                        raise ValueError('Unsupported versionCode representation')
                    version_offset = offset+16
            elements.append({'element': strings[name], 'attributes': attrs})
        pos += size
    return elements, version_offset

def set_version(data, version):
    elements, offset = inspect(data)
    if offset is None:
        raise ValueError('Missing versionCode')
    current = elements[0]['attributes']['versionCode']
    if not current < version <= 2100000000:
        raise ValueError('versionCode must increase and be valid for Android')
    result = bytearray(data)
    struct.pack_into('<I', result, offset, version)
    assert result[:offset] == data[:offset] and result[offset+4:] == data[offset+4:]
    return bytes(result)

def set_version_name(data, name):
    elements, _ = inspect(data)
    old = elements[0]['attributes']['versionName']
    if len(name) != len(old) or not name.isascii():
        raise ValueError('This preservation build requires a same-length ASCII versionName')
    for encoding in ['utf-16le', 'utf-8']:
        before, after = old.encode(encoding), name.encode(encoding)
        if data.count(before) == 1:
            result = data.replace(before, after, 1)
            observed, _ = inspect(result)
            if observed[0]['attributes']['versionName'] == name:
                return result
    raise ValueError('Cannot safely locate versionName in compiled manifest')
