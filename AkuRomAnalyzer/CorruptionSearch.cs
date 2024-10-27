using System;
using System.Collections.Generic;
using System.Linq;

namespace AkuRomAnalyzer
{
	// Heart of the Rom Analyzer, actually checks if a given corruption can be performed for any region of the game
	public class CorruptionSearch
	{
		private IDictionary<Region, GameData> RomInfo { get; set; }
		private CorruptionSearchParameters Parameters { get; set; }

		public CorruptionSearch(IEnumerable<GameData> romInformation, CorruptionSearchParameters parameters)
		{
			RomInfo = romInformation.ToDictionary(s => s.Region, s => s);
			Parameters = parameters;
		}

		public void Run()
		{
			foreach (var target in Parameters.TargetAddress)
			{
				var targetAddress = target.Value;
				Console.WriteLine($"Region {target.Key}, Target Address: ${targetAddress:X2}\n");
				if (!RomInfo.TryGetValue(target.Key, out var romInfo))
				{
					Console.WriteLine("No ROM with this region loaded! Skipping...\n");
					continue;
				}

				// Now check for the actual corruption
				TestCorruption(romInfo, targetAddress);
			}
		}

		private void TestCorruption(GameData romInfo, ushort targetAddress)
		{
			// Step 1 - Is there a suitable camera position that can corrupt the target value?
			// For this, we check if there is an (invalid) value in the mod 6 table that can be added to
			// the address of one of the 6-byte OBJ tables to overwrite the target value.
			// 
			// If no value is found, no memory corruption could ever work.

			Console.WriteLine("i.   Searching for camera positions to corrupt target address...\n");

			var okMod6Offsets = new Dictionary<ushort, List<int>>();
			foreach (var objRamTable in StaticGameData.ObjRamTables)
				okMod6Offsets[objRamTable] = new List<int>();

			for (int i = StaticGameData.Mod6TableSize; i < romInfo.Mod6Table.Length; i++)
				foreach (var objRamTable in StaticGameData.ObjRamTables)
					if (((objRamTable + romInfo.Mod6Table[i]) & 0x7FF) == targetAddress)
						okMod6Offsets[objRamTable].Add(i);

			foreach (var okMod6Offset in okMod6Offsets)
			{
				var targetTable = okMod6Offset.Key;
				foreach (var index in okMod6Offset.Value)
				{
					var offset = romInfo.Mod6Table[index];
					Console.Write($"Offset {FormatUtil.ShowColumn(index)} - Can corrupt {FormatUtil.ShowCorruptWrite(targetTable, offset)}");
					switch (targetTable)
					{
						case 0x7C8: Console.WriteLine("   [ 0 ]"); break;
						case 0x7DA: Console.WriteLine("   [ * ]    (depends on $09)"); break;
						case 0x7E0: Console.WriteLine("   [ 0, 1 ] (depends on $09)"); break;
						default: Console.WriteLine(); break;
					}
				}
			}
			Console.WriteLine();

			// Step 2 - Find good objects in the static OBJ table that can provide the desired target value.
			// If we figured out in the previous step that we need to e.g., write to table 0x7C2 with a given offset, we want to find
			// an object where the first byte is the target value, since the first byte is what's written into 0x7C2,x.
			//
			// If no object is found here, one could still corrupt the object index pointer at $98 (U) or $95 (J) to contain an 
			// invalid object ID, which would in turn allow us to theoretically fetch an object from RAM. Note that in this case,
			// hard mode must be enabled, because otherwise, the game will not permit invalid objects to be read.

			Console.WriteLine("ii.  Searching for objects that can provide the target value...\n");

			var okObjWrites = new List<ObjRamWrite>();
			for (int objIdx = 0; objIdx < romInfo.ObjTable.Length; objIdx++)
			{
				if (!romInfo.TryGetObj(objIdx, out var objData))
					continue;

				// Reconstruct the sequence of OBJ writes from the ASM code here here

				// Byte 0 -> $7C2, if 0 further processing stops
				if (Parameters.TargetPredicate.Matches(objData[0]) && okMod6Offsets[0x7C2].Any())
					okObjWrites.Add(new ObjRamWrite(objIdx, 0x7C2, objData[0], 0));
				if (objData[0] == 0)
					continue;

				// Byte 1 -> $7DA, it is added to $09 in RAM and therefore unpredicatble
				// Technically, it also depends on the camera position and should therefore be
				// predictable, but I'm not working out the assembly code right now
				// See here for more info: https://github.com/vinheim3/castlevania3-disasm/blob/main/code/bank14.s#L161

				// 0/1 -> $7E0. Since we cannot predict the result of byte 1, we also forego this byte

				// Byte 2 -> $7D4
				if (Parameters.TargetPredicate.Matches(objData[2]) && okMod6Offsets[0x7D4].Any())
					okObjWrites.Add(new ObjRamWrite(objIdx, 0x7D4, objData[2], 2));

				// Byte 3 -> $7E6
				if (Parameters.TargetPredicate.Matches(objData[3]) && okMod6Offsets[0x7E6].Any())
					okObjWrites.Add(new ObjRamWrite(objIdx, 0x7E6, objData[3], 3));

				// Byte 4 -> $7CE
				if (Parameters.TargetPredicate.Matches(objData[4]) && okMod6Offsets[0x7CE].Any())
					okObjWrites.Add(new ObjRamWrite(objIdx, 0x7CE, objData[4], 4));

				// 0 -> $7C8
				if (Parameters.TargetPredicate.Matches(0) && okMod6Offsets[0x7C8].Any())
					okObjWrites.Add(new ObjRamWrite(objIdx, 0x7C8, 0, ObjRamWrite.NoObjByte));
			}

			foreach (var mod6Offsets in okMod6Offsets)
			{
				foreach (var offset in mod6Offsets.Value)
				{
					foreach (var obj in okObjWrites.Where(s => s.TargetObjTable == mod6Offsets.Key))
					{
						var mod6Offset = romInfo.Mod6Table[offset];
						var realTargetAddress = (obj.TargetObjTable + mod6Offset) & 0x7FF;
						Console.Write($"Offset {FormatUtil.ShowColumn(offset)} - Can write value ${obj.TargetValue:X2} from {FormatUtil.ShowObj(obj)} to {FormatUtil.ShowCorruptWrite(obj.TargetObjTable, mod6Offset)}");
						Console.WriteLine(FormatUtil.ShowObjProperties(obj));
					}
				}
			}
			Console.WriteLine();

			// Step 3 - Try to find good object index from the game's room data in ROM.
			// Each room is divided into 64-pixel strips, each of which can have one OBJ index associated with it.
			// In the previous step, we figured out which combination of camera position and object ID we need to corrupt a given address with
			// a given value. We now check the room data for every room in the game to see if a room provides an object with the right index.
			// Note that, because the camera position must be out-of-bounds, the actual room data is also read out-of-bounds, which usually 
			// means fetching the data from a subsequent room, or some random data in ROM.
			//
			// If no result is found here, memory corruption can still be made to work by corrupting the obj index pointer at $98 (U) or $95 (J),
			// which allows us to fetch any object index from RAM. In practice, this is how the current wrong warp works.

			Console.WriteLine("iii. Searching for rooms in the game that define a matching object at the given camera offset...\n");

			var okObjWritesByIndex = okObjWrites.GroupBy(s => s.ObjIndex);
			foreach (var (block, sublevel, room) in StaticGameData.RoomIndices)
			{
				foreach (var okMod6Offset in okMod6Offsets)
				{
					foreach (var offset in okMod6Offset.Value)
					{
						var goodObjects = okObjWritesByIndex
							.Where(s => s.Key == romInfo.GetRoomObjIdx(block, sublevel, room, offset))
							.SelectMany(s => s)
							.Where(s => s.TargetObjTable == okMod6Offset.Key);
						foreach (var obj in goodObjects)
						{
							var mod6Offset = romInfo.Mod6Table[offset];
							Console.Write($"Block {block:X1}, Sublevel {sublevel:X1} ({FormatUtil.FormatBlock(block, sublevel)}), Room {room}, Column {FormatUtil.ShowColumn(offset)}");
							Console.Write($"   << [${romInfo.BaseOffsets.ObjIdxPtr:X2}]: ${romInfo.GetRoomDataPtr(block, sublevel, room):X4}");
							Console.Write($" [${romInfo.BaseOffsets.ObjIdxPtr:X2},${romInfo.BaseOffsets.LoadColumn:X2}]: ${romInfo.GetRoomDataPtr(block, sublevel, room, offset):X4} >>  ");
							Console.Write($" - Writing value ${obj.TargetValue:X2} from {FormatUtil.ShowObj(obj)} to {FormatUtil.ShowCorruptWrite(obj.TargetObjTable, mod6Offset)}");
							Console.WriteLine(FormatUtil.ShowObjProperties(obj));
						}
					}
				}
			}
			Console.WriteLine();
		}
	}
}
