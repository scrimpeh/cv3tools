using AkuRomAnalyzer.Extensions.ByteArray;
using System;
using System.Collections.Generic;

namespace AkuRomAnalyzer
{
	/// <summary>
	/// Contains all of the relevant information for the game
	/// </summary>
	public class GameData
	{
		private static readonly IDictionary<Region, DataBaseOffsets> regionBaseOffsets = new Dictionary<Region, DataBaseOffsets>()
		{
			{ Region.Us,    new DataBaseOffsets(0x76, 0x98, 0x840C, 0xA03F, 0x937F) },
			{ Region.Japan, new DataBaseOffsets(0x73, 0x95, 0x8410, 0x9F6E, 0x92AE) }
		};

		private readonly RomLoader romLoader;

		public const int ObjDataBankIndex = 10;

		public RomType RomType => romLoader.RomType;
		public Region Region => romLoader.Region;
		public byte[][] PrgBanks => romLoader.PrgRom;

		internal DataBaseOffsets BaseOffsets => regionBaseOffsets[Region];

		public byte[] ObjDataBank => romLoader.PrgRom[ObjDataBankIndex];
		public byte[] FixedBank => romLoader.PrgRom[15];

		// Static Game Data relevant for Memory Corruption
		public byte[] Mod6Table { get; private set; }
		public ushort[] ObjTable { get; private set; }

		public ushort[] BlockToSublevelData { get; private set; }
		public ushort[][] SublevelToRoomData { get; private set; }
		public ushort[][][] RoomToObjData { get; private set; }

		public GameData(string path)
		{
			romLoader = new RomLoader(path);

			// Get Static Game Data
			Mod6Table = ObjDataBank.ReadBytes(BaseOffsets.Mod6Table, 256);
			ObjTable = ObjDataBank.ReadWords(BaseOffsets.ObjTable, 256);

			GetRoomPointerTables();
		}

		private void GetRoomPointerTables()
		{
			// Get Block To Sublevel Data
			BlockToSublevelData = ObjDataBank.ReadWords(BaseOffsets.BlockPointerTable, StaticGameData.Blocks.Count);

			// Get Sublevel To Room Data
			SublevelToRoomData = new ushort[StaticGameData.Blocks.Count][];
			RoomToObjData = new ushort[StaticGameData.Blocks.Count][][];
			for (var block = 0; block < StaticGameData.Blocks.Count; block++)
			{
				var sublevelInfo = StaticGameData.Blocks[block].Sublevels;
				SublevelToRoomData[block] = ObjDataBank.ReadWords(BlockToSublevelData[block], sublevelInfo.Count);
				RoomToObjData[block] = new ushort[sublevelInfo.Count][];
				for (var sublevel = 0; sublevel < sublevelInfo.Count; sublevel++)
					RoomToObjData[block][sublevel] = ObjDataBank.ReadWords(SublevelToRoomData[block][sublevel], sublevelInfo[sublevel].RoomCount);
			}
		}

		public ushort GetRoomDataPtr(int block, int sublevel, int room)
			=> RoomToObjData[block][sublevel][room];

		public ushort GetRoomDataPtr(int block, int sublevel, int room, int column)
			=> (ushort)(RoomToObjData[block][sublevel][room] + ((column & 0x7F) * 2));

		public byte GetRoomObjIdx(int block, int sublevel, int room, int cameraBlock)
		{
			cameraBlock &= 0x7F;
			var roomDataPtr = GetRoomDataPtr(block, sublevel, room) & 0x3FFF;
			return ObjDataBank[roomDataPtr + cameraBlock * 2];
		}

		public bool TryGetObj(int idx, out byte[] obj)
		{
			obj = new byte[5];
			var objPtr = ObjTable[idx];

			if (objPtr < 0x8000)
				return false;

			var sourceBank = objPtr < 0xC000 ? ObjDataBank : FixedBank;
			Array.Copy(sourceBank, objPtr & 0x3FFF, obj, 0, 5);
			return true;
		}
	}

	public struct DataBaseOffsets
	{
		public byte LoadColumn { get; private set; }
		public byte ObjIdxPtr { get; private set; }
		public ushort Mod6Table { get; private set; }
		public ushort ObjTable { get; private set; }
		public ushort BlockPointerTable { get; private set; }

		public DataBaseOffsets(byte loadColumn, byte objIdxPtr, ushort mod6Table, ushort objTable, ushort blockPointerTable) 
		{
			LoadColumn = loadColumn;
			ObjIdxPtr = objIdxPtr;
			Mod6Table = mod6Table;
			ObjTable = objTable;
			BlockPointerTable = blockPointerTable;
		}
	}
}
