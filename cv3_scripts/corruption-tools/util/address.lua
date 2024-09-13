-- Basic functions for handling addresses - handles conversion between 
-- an address in the 6502 address space and the ROM bank we are interested in

function prg_rom(addr_adr)
	return addr_adr | 0x20000
end

function prg_bank(addr_rom)
	return 0x8000 | (addr_rom & 0x7FFF)
end