using System;

namespace AkuRomAnalyzer.Extensions.ByteArray
{
	public static class ByteArrayExtensions
	{
		public static ushort ReadWordAndInc(this byte[] array, ref int offset, bool littleEndian = true)
		{
			var a = array[offset++];
			var b = array[offset++];
			return (ushort)(littleEndian ? ((b << 8) | a) : ((a << 8) | b));
		}

		public static ushort ReadWord(this byte[] array, int offset, bool littleEndian = true)
		{
			var a = array[offset];
			var b = array[offset + 1];
			return (ushort)(littleEndian ? ((b << 8) | a) : ((a << 8) | b));
		}

		public static byte[] ReadBytes(this byte[] array, int offset, int size)
		{
			var bytes = new byte[size];
			Array.Copy(array, offset & 0x3FFF, bytes, 0, size);
			return bytes;
		}

		public static ushort[] ReadWords(this byte[] array, int offset, int count)
		{
			var words = new ushort[count];
			var readOffset = offset & 0x3FFF;
			// We deliberately do not allow automatic wrapping here
			for (var i = 0; i < count; i++)
				words[i] = ReadWordAndInc(array, ref readOffset);
			return words;
		}

		public static ushort ReadWordBank(this byte[] array, int offset, bool littleEndian = true)
			=> ReadWord(array, offset & 0x3FFF, littleEndian);

		public static ushort ReadWordBankInc(this byte[] array, ref int offset, bool littleEndian = true)
		{
			var a = array[offset & 0x3FFF];
			var b = array[(offset + 1) & 0x3FFF];
			offset += 2;
			return (ushort)(littleEndian ? ((b << 8) | a) : ((a << 8) | b));
		}
	}
}
