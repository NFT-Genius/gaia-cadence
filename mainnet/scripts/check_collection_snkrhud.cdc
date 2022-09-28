import SNKRHUDNFT from 0x80af1db15aa6535a

pub fun main(address: Address): Bool {
  return getAccount(address)
    .getCapability<&{SNKRHUDNFT.CollectionPublic}>(SNKRHUDNFT.CollectionPublicPath)
    .check()
}
