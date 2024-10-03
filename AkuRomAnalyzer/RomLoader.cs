using System;
using System.IO;
using System.Linq;

namespace AkuRomAnalyzer
{
	public class RomLoader
	{
		private readonly byte[] InesHeader = { 0x4E, 0x45, 0x53, 0x1A };

		public byte[][] PrgRom { get; private set; }
		public RomType RomType { get; private set; }
		public Region Region { get; private set; }

		public RomLoader(string path)
		{
			var rawRom = File.ReadAllBytes(path);

			// Get ROM data
			var extension = Path.GetExtension(path);
			var assumedRomType = RomType.Unsupported;
			if (extension == ".nes")
				assumedRomType = RomType.Ines;

			switch (assumedRomType)
			{
				case RomType.Ines:
					GetInesRomData(path, rawRom);
					break;
				default:
					throw new InvalidOperationException($"Unrecognized ROM file: {path}");
			}
		}

		private void GetInesRomData(string path, byte[] rawRom)
		{
			if (!Enumerable.SequenceEqual(rawRom.Take(4), InesHeader)) 
				throw new InvalidOperationException($"Unexpected Header for file {path}!");

			// Validate Game-Specific Data
			// Castlevania 3 ROM has 256 kb of PRG rom and 128 kb of CHR Rom in both regions
			// Mapper MMC5 (5) in U, and mapper VRC6a (24) for J
			var prgBanks = rawRom[4];
			var chrBanks = rawRom[5];
			if (prgBanks != 16 || chrBanks != 16)
				throw new InvalidOperationException($"Unexpected Header for file {path}!");

			var mapper = (rawRom[7] & 0xF0) | (rawRom[6] >> 4);
			switch (mapper) 
			{
				case 5:  Region = Region.Us;    break;
				case 24: Region = Region.Japan; break;
				default: throw new InvalidOperationException($"Unexpected Mapper for file {path}: {mapper}!");
			}

			// Extract PRG ROM in 16 KiB banks
			var trained = (rawRom[6] & 0x4) != 0;
			var prgStart = trained ? 528 : 16;
			PrgRom = new byte[prgBanks][];
			for (var i = 0; i < prgBanks; i++) 
			{
				PrgRom[i] = new byte[0x4000];
				Array.Copy(rawRom, prgStart + 0x4000 * i, PrgRom[i], 0, 0x4000);
			}
		}
	}

	public enum RomType
	{
		Ines,
		Unsupported
	}
}
