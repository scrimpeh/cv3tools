namespace AkuRomAnalyzer
{
	/// <summary>
	/// Data class which holds information about a potential write from the OBJ table into RAM
	/// </summary>
	public class ObjRamWrite
	{
		public const byte NoObjByte = 255;

		public int ObjIndex { get; private set; }
		public ushort TargetObjTable { get; private set; }
		public byte TargetValue { get; private set; }
		public byte ObjByte { get; private set; }

		public bool HardModeOnly => ObjIndex >= 208;
		public bool Invalid => ObjIndex >= 228;

		public ObjRamWrite(int objIndex, ushort targetObjTable, byte targetValue, byte objByte = NoObjByte)
		{
			ObjIndex = objIndex;
			TargetObjTable = targetObjTable;
			TargetValue = targetValue;
			ObjByte = objByte;
		}
	}
}
