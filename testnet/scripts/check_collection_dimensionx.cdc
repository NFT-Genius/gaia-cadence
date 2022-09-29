import DimensionX from 0x46664e2033f9853d

pub fun main(address: Address): Bool {
  return getAccount(address)
    .getCapability<&{DimensionX.CollectionPublic}>(DimensionX.CollectionPublicPath)
    .check()
}
