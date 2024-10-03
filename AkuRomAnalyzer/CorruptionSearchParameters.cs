﻿using System.Collections.Generic;
using System.Linq;

namespace AkuRomAnalyzer
{
	/// <summary>
	/// Basic data class that describes the parameters of a corruption search
	/// </summary>
	public class CorruptionSearchParameters
	{
		public const ushort Unknown = 0xFFFF;

		public IDictionary<Region, ushort> TargetAddress { get; private set; }
		public IList<byte> TargetValues { get; private set; }

		public CorruptionSearchParameters(ushort targetAddressU, ushort targetAddressJ, params byte[] targetValues)
		{
			TargetAddress = new Dictionary<Region, ushort>();
			if (targetAddressU != Unknown)
				TargetAddress[Region.Us] = targetAddressU;
			if (targetAddressJ != Unknown)
				TargetAddress[Region.Japan] = targetAddressJ;

			TargetValues = targetValues.ToList();
		}
	}
}