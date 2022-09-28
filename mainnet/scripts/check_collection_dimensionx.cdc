import DimensionX from 0xe3ad6030cbaff1c2

pub fun main(address: Address): Bool {
  return getAccount(address)
    .getCapability<&{DimensionX.CollectionPublic}>(DimensionX.CollectionPublicPath)
    .check()
}
