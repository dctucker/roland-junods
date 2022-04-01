import memorymap
import macros

dumpTree:
  let mfx = @[
    CM( 0x00, "type"       , TByte, 0, 80),
    CM( 0x01, "dry_send"   , TByte, 0, 127),
  ]


dumpTree:
  0x01000000 setup: setup
  0x02000000 system: system
  temporary:
    0x10000000 performance_pattern: performance_pattern
    0x11000000 performance_part:    performance_parts
    0x1e000000 rhythm_pattern:      arpeggio
    0x1e110000 arpeggio:            arpeggio
    0x1e130000 rhythm_group:        rhythm_group
    0x1e150000 vocal_effect:        vocal_effect
    0x1f000000 patch_part: # patch mode part 1
      0x000000 1: patch_drum
      0x200000 2: patch_drum
  user:
    0x20000000 performance:  performance_patterns
    0x21000000 pattern:      performance_patterns
    0x30000000 patch:        performance_patches
    0x40000000 drum_kit:     drum_kits
    0x60000000 vocal_effect: vocal_effects

proc nnkCM(offset: BiggestInt, name: string, stmtlist: NimNode): NimNode =
  result = newLit( CMA(offset, name, @[]) )

proc diveMap(input: NimNode): NimNode =
  result = quote do:
    []
  case input.kind
  of nnkCommand:
    var offset: BiggestInt = 0
    if input[0].kind == nnkIntLit:
      offset = input[0].intVal()
    let name = input[^2].strVal()
    let stmtlist = diveMap(input[^1])
    result.add nnkCM(offset, name, stmtlist)
  of nnkCall:
    let stmtlist = diveMap(input[1])
    result.add quote do:
      CMAO("`input[0]`", `stmtlist`)
  else:
    result.add quote do:
      `input`

macro genMap(statement: untyped): untyped =
  var bracket = quote do:
    []
  for sub in statement:
    bracket.add diveMap(sub)
  result = quote do:
    @`bracket`

let juno_map = genMap:
  0x01000000 setup:
    @[]
