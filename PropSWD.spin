{{
┌─────────────────────────────────────────────────┐
│ ARM Serial Wire Debug                           │
│ Interface Object                                │
│                                                 │
│ Author: Jean-Michel Picod                       │
│                                                 │
│ Distributed under a Creative Commons            │
│ Attribution 3.0 United States license           │
│ http://creativecommons.org/licenses/by/3.0/us/  │
└─────────────────────────────────────────────────┘

}}

CON
  SWD_ACK = %001
  SWD_WAIT = %010
  SWD_FAULT = %100
  SWD_DISCONNECT = %111

  SWD_DP = 0
  SWD_AP = 1

  WRITE = 0
  READ = 1

  PARITY_MASK = %01111000

VAR
  long SWCLK, SWDIO       ' ARM SWD pins (must stay in this order)


OBJ


PUB Config(clk_pin, data_pin)
{
  Set SWD pins
  Parameters : SWCLK, SWDIO channels provided by top object
}
  longmove(@SWCLK, @clk_pin, 2)

PUB Idcode | code, ack, error
  error := ReadDebugPort(0, @ack, @code)
  if (error == 0) and (ack == SWD_ACK)
    return code
  return -1

PUB SendPacket(APnDP, RnW, address) | data, ack, i
{
  TODO

  Parameters : APnDP = Operationg is on DP if 0 otherwise on AP
               RnW = Write operation if 0 otherwise read
               address = Address to read
  Returns    : ACK value (3 bits)
}

  data := %10000001 | ((address & 3) << 3) | ((RnW & 1) << 5)
  ' Set parity
  data[2] := ComputeParity(((data & PARITY_MASK) >> 3), 4)

  WriteDataBits(data, 8)
  TRN
  return ReadDataBits(3)

PUB SWDRead(APnDP, address, ack_ptr, value_ptr) | ack, data, parity
  data := 0
  parity := 0
  ack := SendPacket(APnDP, READ, address)
  byte[ack_ptr][0] := ack & 3
  if (ack == SWD_ACK)
    data := ReadDataBits(32)
    long[value_ptr][0] := data
    parity := ReadDataBits(1)
    TRN
    return parity == ComputeParity(data, 32)
  TRN
  return FALSE

PUB SWDWrite(APnDP, address, value) | parity, ack
  parity := ComputeParity(value, 32)
  ack := SendPacket(APnDP, WRITE, address)
  TRN
  if (ack == SWD_ACK)
    WriteDataBits(value, 32)
    WriteDataBits(parity, 1)
  return ack

PUB ReadDebugPort(address, ack_ptr, value_ptr)
  return SWDRead(SWD_DP, address, ack_ptr, value_ptr)

PUB ReadAccessPort(address, ack_ptr, value_ptr)
  return SWDRead(SWD_AP, address, ack_ptr, value_ptr)

PUB WriteDebugPort(address, value)
  return SWDWrite(SWD_DP, address, value)

PUB WriteAccessPort(address, value)
  return SWDWrite(SWD_AP, address, value)

PUB Reset | i
  repeat i from 1 to 8
    WriteDataBits($ffffffff, 32)
  repeat i from 1 to 8
    WriteDataBits(0, 32)

PUB Jtag2SWD
  Reset
  WriteDataBits($e79e, 16)
  Reset


PRI ComputeParity(value, nb_bits) | parity, i
  parity := 0
  repeat i from 1 to nb_bits
    parity ^= (value & 1)
    value >>= 1
  return parity

PRI ReadDataBits(nb_bits) | value, i
  dira[SWDIO] := 0
  value := 0
  repeat i from 1 to nb_bits
    !outa[SWCLK]
    !outa[SWCLK]
    value <<= 1
    value |= ina[SWDIO] & 1
  return value >< nb_bits

PRI WriteDataBits(value, nb_bits) | i
  dira[SWDIO] := 1
  value ><= nb_bits
  repeat i from 1 to nb_bits
    outa[SWDIO] := value & 1
    !outa[SWCLK]
    !outa[SWCLK]
    value >>= 1

PRI TRN
  ' Waste a CLK cycle.
  !outa[SWCLK]
  !outa[SWCLK]

DAT
