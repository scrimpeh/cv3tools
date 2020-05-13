using System;
using System.IO;

namespace AkuRomAnaylzer
{
	public class RomLoader
	{
		/// <summary>
		/// The 16 KiB PRG rom bank where the game keeps its level data.
		/// The same for both J and U releases of the game
		/// </summary>
		public const int LevelDataBank = 10;

		public byte[] PrgRom { get; private set; }
		public byte[] PrgDataBank { get; private set; }
		public RomType RomType { get; private set; }
		public Region Region { get; private set; }
		public long Size { get; private set; }
		public string RomPath { get; private set; }


		public RomLoader(string path, Region region)
		{
			// Now read the rom
			byte[] rawRom = null;
			RomPath = path;
			Region = region;
			RomType = RomType.Unsupported;

			rawRom = File.ReadAllBytes(path);
			RomType = GuessRomType(path, rawRom);
			
			if (!ValidateRom(rawRom, region, RomType))
			{
				throw new Exception("Error validating ROM file! ROM header doesn't match expected ROM");
			}

			// Extract PRG rom
			var trained = (rawRom[6] & 0x4) != 0;
			var prgStart = trained ? 528 : 16;
			var Size = rawRom[4] * 16384;
			PrgRom = new byte[Size];
			Array.Copy(rawRom, prgStart, PrgRom, 0, Size);
			
			var levelDataOffset = LevelDataBank * 16384;
			PrgDataBank = new byte[16384];	// node that offsets from the game code need to be masked with 0x3FFF 
			Array.Copy(PrgRom, levelDataOffset, PrgDataBank, 0, PrgDataBank.Length);
		}

		private bool ValidateRom(byte[] raw, Region region, RomType type)
		{
			// Castlevania 3 ROM has 256 kb of PRG rom and 128 kb of CHR Rom in both regions
			// Mapper MMC5 (5) in U, and mapper VRC6a (24) for J
			switch (type)
			{
				case RomType.Ines:
					{
						var expectedMapper = region == Region.Japan ? 24 : 5;
						var prgBanks = raw[4];
						var chrBanks = raw[5];
						var mapper = (raw[7] & 0xF0) | (raw[6] >> 4);
						if (prgBanks != 16 || chrBanks != 16 || mapper != expectedMapper)
						{
							return false;
						}
						return true;
					}
			}
			return false;
		}

		private RomType GuessRomType(string path, byte[] raw)
		{
			var assumedRomType = RomType.Unsupported;

			// First, look at the filename
			var extension = Path.GetExtension(path);
			if (extension == ".nes")
			{
				assumedRomType = RomType.Ines;
			}

			// Now, look at the header
			if (raw.Length < 16)
			{
				throw new Exception("ROM too small!");
			}

			switch (assumedRomType)
			{
				case RomType.Ines:
					if (raw[0] == 0x4E && raw[1] == 0x45 && raw[2] == 0x53 && raw[3] == 0x1A)
					{
						return RomType.Ines;
					}
					break;
			}

			throw new Exception("Cannot guess Rom Type!");
		}
	}

	public enum RomType
	{
		Ines,
		Unsupported
	}
}
