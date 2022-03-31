import memorymap

type
  Cache* = object
    storage: array[0xc003fff,byte]

var cache*: ref Cache

proc initCache*() =
  cache = new Cache

proc offset_to_storage(offset: JAddr): int64 =
  let o3 = ((offset and 0x7f000000) shr 3)
  let o2 = ((offset and 0x007f0000) shr 2)
  let o1 = ((offset and 0x00007f00) shr 1)
  let o0 = ((offset and 0x0000007f)      )
  result = o3 or o2 or o1 or o0

proc cache_get*(offset: JAddr, kind: Kind): seq[byte] =
  let pos = offset_to_storage(offset)
  let tlen = case kind
  of TBool, TNibble, TEnum, TByte: 1
  of TNibblePair: 2
  of TNibbleQuad: 4
  of TName: 12
  of TName16: 16
  else: 0

  if tlen == 0:
    return @[]
  return cache.storage[pos..pos+tlen-1]

proc cache_set*(offset: JAddr, value: seq[byte]) =
  let pos = offset_to_storage(offset)
  for i in 0..value.high:
    cache.storage[pos + i] = value[i]

