import strutils
import memorymap
import macros

#dumpTree:
#  @[
#    Mem(offset: 0, name: "temporary"),
#    Mem(offset: 1, name: "performance", area: @[
#      Mem(offset: 10, name: "patch"),
#    ]),
#  ]

#dumpTree:
#  let mfx = @[
#    CM( 0x00, "type"       , TByte, 0, 80),
#    CM( 0x01, "dry_send"   , TByte, 0, 127),
#  ]

