namespace AkuRomAnaylzer.Extensions.ByteArray
{
	public static class ByteArrayExtensions
	{
		public static int ReadWordAndInc(this byte[] array, ref int offset, bool littleEndian = true)
		{
			var a = array[offset++];
			var b = array[offset++];
			return littleEndian ? ((b << 8) | a) : ((a << 8) | b);
		}

		public static int ReadWord(this byte[] array, int offset, bool littleEndian = true)
		{
			var a = array[offset];
			var b = array[offset + 1];
			return littleEndian ? ((b << 8) | a) : ((a << 8) | b);
		}
	}
}
