using System;
using System.IO;
using System.Linq;

namespace AkuRomAnalyzer.Misc
{
	/// <summary>
	/// Extracts the OBJ Data from the game and parses it to a CSV file
	/// </summary>
	internal static class ObjExtractor
	{
		public static void _Main(string[] args) 
		{
			Console.WriteLine("Extracting OBJ Info...");
			if (args.Length <= 1)
			{
				Console.WriteLine("Must pass output directory and CV3 ROM files!");
				Environment.Exit(1);
			}

			var baseDirectory = args[0];
			foreach (var rom in args.Skip(1))
			{
				var gameData = new GameData(rom);
				var outputFilePath = Path.Combine(baseDirectory, $"OBJ_{gameData.Region}.csv");
				Console.WriteLine("Writing to " + outputFilePath + "...");
				using (var fileWriter = new StreamWriter(outputFilePath))
				{
					fileWriter.WriteLine("Index;Pointer Adr;OBJ Adr;Hard Mode;Invalid;Byte 0;Byte 1;Byte 2;Byte 3;Byte 4");
					for (var i = 0; i < 256; i++)
					{
						var record = new CsvRecord(gameData, i);
						fileWriter.WriteLine(record.Format());
					}
				}
			}
			Console.WriteLine("Done");
		}

		public class CsvRecord
		{
			public int Index { get; private set; }
			public ushort ObjPtrAdr { get; private set; }
			public ushort ObjAdr { get; private set; }

			public bool HardMode => Index >= 208;
			public bool Invalid => Index >= 228;

			public byte[] Content { get; private set; }

			public CsvRecord(GameData data, int index)
			{
				Index = index;
				ObjPtrAdr = (ushort)(data.BaseOffsets.ObjTable + index * 2);
				ObjAdr = data.ObjTable[index];

				data.TryGetObj(index, out var content);
				Content = content;
			}

			public string Format()
				=> $"{Index};${ObjPtrAdr:X4};${ObjAdr:X4};{FormatBool(HardMode)};{FormatBool(Invalid)};{(ObjAdr < 0x8000 ? "" : string.Join(";", FormatUtil.ToHex(Content)))}";

			public static string FormatBool(bool b) => b ? "Yes" : "No";
		}
	}
}
