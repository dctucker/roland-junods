import memorymap
import macros

dumpTree:
  @[
    Mem(offset: 0, name: "temporary"),
    Mem(offset: 1, name: "performance", area: @[
      Mem(offset: 10, name: "patch"),
    ]),
  ]

#dumpTree:
#  let mfx = @[
#    CM( 0x00, "type"       , TByte, 0, 80),
#    CM( 0x01, "dry_send"   , TByte, 0, 127),
#  ]


#dumpTree:
#  0x01000000 setup: setup
#  0x02000000 system: system
#  temporary:
#    0x10000000 performance_pattern: performance_pattern
#    0x11000000 performance_part:    performance_parts
#    0x1e000000 rhythm_pattern:      arpeggio
#    0x1e110000 arpeggio:            arpeggio
#    0x1e130000 rhythm_group:        rhythm_group
#    0x1e150000 vocal_effect:        vocal_effect
#    0x1f000000 patch_part: # patch mode part 1
#      0x000000 1: patch_drum
#      0x200000 2: patch_drum
#  user:
#    0x20000000 performance:  performance_patterns
#    0x21000000 pattern:      performance_patterns
#    0x30000000 patch:        performance_patches
#    0x40000000 drum_kit:     drum_kits
#    0x60000000 vocal_effect: vocal_effects

proc diveMap(input: NimNode): NimNode =
  result = quote do:
    []
  #echo input.kind
  case input.kind
  of nnkStmtList:
    if input.len() == 1 and input[0].kind == nnkStmtList:
      result = input[0]
    else:
      for stmt in input:
        result.add( diveMap(stmt) )
  of nnkCommand:
    var offset: BiggestInt = -1
    if input[0].kind == nnkIntLit:
      offset = input[0].intVal()
    let name = input[1].strVal()
    if input.len() >= 3:
      let areas = diveMap(input[2])
      for area in areas:
        echo "area = " , area.treeRepr
        if area.kind == nnkBracket:
          for m in area:
            result.add quote do:
              Mem( offset: `offset`, name: `name`, area: `m`)
        else:
          result.add quote do:
            Mem( offset: `offset`, name: `name`, area: `area`)
    else:
      result = quote do:
        Mem( offset: `offset`, name: `name`)
    #echo "name = " & name.repr
  of nnkCall:
    let name = newLit( $input[0].strVal() )
    result = quote do:
      Mem( name: `name`, area: @[])
    input[0].expectKind(nnkIdent)
    var stmtlist = diveMap(input[1])
    if stmtlist.kind == nnkBracket:
      for stmt in stmtlist:
        result[^1][^1][^1].add(stmt)
    else:
      echo "stmtlist kind = " & $stmtlist.kind
      result[^1][^1][^1].add(stmtlist)
  of nnkIdent:
    result = input
  else:
    result = quote do:
      `input`

macro genMap(statement: untyped): untyped =
  echo "input ast = " & statement.treeRepr
  var bracket = quote do:
    []
  for sub in statement:
    let dive = diveMap(sub)
    if dive.kind == nnkBracket:
      for d in dive:
        bracket.add d
    else:
      bracket.add dive
  result = quote do:
    @`bracket`
  echo "output ast = " & result.treeRepr
  echo result.repr

let system: MemArea = @[]
let performance_pattern: MemArea = @[]
let performance_parts: MemArea = @[]
let arpeggio: MemArea = @[]
let rhythm_group: MemArea = @[]
let vocal_effect: MemArea = @[]
let patch_drum: MemArea = @[]
let drum_kits: MemArea = @[]

let setup = genMap: 0 common: @[]
let juno_map = genMap:
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
      0x000000 x1: patch_drum
      0x200000 x2: patch_drum
  user:
    0x20000000 performance:  performance_patterns
    0x21000000 pattern:      performance_patterns
    0x30000000 patch:        performance_patches
    0x40000000 drum_kit:     drum_kits
    0x60000000 vocal_effect: vocal_effects
