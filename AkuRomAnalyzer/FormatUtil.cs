using System.Collections.Generic;
using System.Linq;

namespace AkuRomAnalyzer
{
	public static class FormatUtil
	{
		public static IEnumerable<string> ToHex(IEnumerable<byte> values)
			=> values.Select(s => $"${s:X2}");

		public static IEnumerable<string> ToHex(IEnumerable<ushort> values)
			=> values.Select(s => $"${s:X4}");

		public static string ShowColumn(int column)
			=> $"${column:X2} (Cam: {column * 64,5:#####} / ${column * 64:X4})";

		public static string ShowObj(ObjRamWrite obj)
			=> $"OBJ ${obj.ObjIndex:X2} (byte {(obj.ObjByte == ObjRamWrite.NoObjByte ? "-": obj.ObjByte.ToString())})";

		public static string ShowCorruptWrite(ushort targetTable, byte targetOffset)
			=> $"${targetTable:X} + ${targetOffset:X2} -> ${(targetTable + targetOffset) & 0x7FF:X2}";

		public static string FormatBlock(int block, int sublevel)
			=> $"{StaticGameData.Blocks[block].Letter}-{StaticGameData.Blocks[block].Sublevels[sublevel].Letter}";

		public static string ShowObjProperties(ObjRamWrite obj)
			=> obj.Invalid ? "   (Invalid Object)" : (obj.HardModeOnly ? "   (Hard Mode)" : string.Empty);
		
	}
}
