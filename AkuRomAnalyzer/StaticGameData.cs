using System.Collections.Generic;
using System.Linq;

namespace AkuRomAnalyzer
{
	public static class StaticGameData
	{
		public static readonly List<BlockInfo> Blocks = new List<BlockInfo>()
		{
			new BlockInfo('1', "Village",     ("01", 1), ("02", 4), ("03", 2), ("04", 1)),
			new BlockInfo('2', "Clock Tower", ("01", 3), ("02", 3), ("03", 3), ("04", 3), ("05", 3), ("06", 3)),
			new BlockInfo('3', "Mad Forest",  ("00", 2), ("01", 1), ("02", 2), ("03", 3), ("04", 2)),
			new BlockInfo('4', "Ghost Ship",  ("0A", 3), ("0B", 2), ("0C", 2), ("0D", 2), ("0E", 3)),
			new BlockInfo('5', "Death Tower", ("0A", 3), ("0B", 3), ("0C", 3)),
			new BlockInfo('6', "Bridge",      ("0A", 1), ("0B", 1), ("0C", 2), ("0D", 2)),
			new BlockInfo('4', "Swamp",       ("01", 2), ("02", 1), ("03", 3)),
			new BlockInfo('5', "Caves",       ("01", 2), ("02", 1), ("03", 1), ("04", 1), ("05", 2), ("06", 2), ("07", 1)),
			new BlockInfo('6', "Sunken City", ("01", 2), ("02", 1), ("03", 2), ("04", 1), ("05", 1)),
			new BlockInfo('6', "Crypt",       ("01", 2), ("02", 3)),
			new BlockInfo('7', "Cliffs",      ("01", 2), ("02", 1), ("03", 1), ("04", 2), ("05", 3), ("06", 2), ("07", 3)),
			new BlockInfo('7', "Aquarius",    ("0A", 2), ("0B", 2), ("0C", 3)),
			new BlockInfo('8', "Deva Vu",     ("01", 2), ("02", 2), ("03", 1)),
			new BlockInfo('9', "Riddle",      ("01", 3), ("02", 3), ("03", 3), ("04", 2)),
			new BlockInfo('A', "Pressure",    ("01", 3), ("02", 2), ("03", 2))
		};

		public const byte Mod6TableSize = 48;
		public const int MaxAllowedCamera = Mod6TableSize * 48;

		public const int ObjCount = 208;
		public const int HardModeObjCount = 228;

		public static readonly IList<ushort> ObjRamTables = new List<ushort>()
		{
			0x7C2, // OBJ Type, any value, if 0, all further writes stop
			0x7DA, // OBJ X, added to $09 in RAM (possibly predictable)
			0x7E0, // OBJ X Hi, either 0 or 1, depending on the carry of 0x7DA,x + $09
			0x7D4, // OBJ Y, any value,
			0x7E6, // Unknown, any value,
			0x7CE, // Timer, any value,
			0x7C8, // OBJ State, always 0
		};
		// TODO: There's more in the 0x400 to 0x600 range, relating to misc. enemy data

		public static IEnumerable<(int block, int sublevel, int room)> RoomIndices
		{
			get
			{
				for (int block = 0; block < Blocks.Count; block++)
					for (int sublevel = 0; sublevel < Blocks[block].Sublevels.Count; sublevel++)
						for (var room = 0; room < Blocks[block].Sublevels[sublevel].RoomCount; room++)
							yield return (block, sublevel, room);
			}
		}
	}

	public struct BlockInfo
	{
		public char Letter { get; private set; }
		public string Name { get; private set; }
		public List<SublevelInfo> Sublevels { get; private set; }

		public BlockInfo(char letter, string name, params (string sublevelLetter, int roomCount)[] sublevels)
		{
			Letter = letter;
			Name = name;
			Sublevels = sublevels
				.Select(sublevelInfo => new SublevelInfo(sublevelInfo.sublevelLetter, sublevelInfo.roomCount))
				.ToList();
		}
	}

	public struct SublevelInfo
	{
		public string Letter { get; private set; }
		public int RoomCount { get; private set; }

		public SublevelInfo(string letter, int roomCount)
		{
			Letter = letter;
			RoomCount = roomCount;
		}
	}
}
