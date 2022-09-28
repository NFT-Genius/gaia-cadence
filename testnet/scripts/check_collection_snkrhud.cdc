import SNKRHUDNFT from 0x9a85ed382b96c857

pub fun main(address: Address): Bool {
  return getAccount(address)
    .getCapability<&{SNKRHUDNFT.CollectionPublic}>(SNKRHUDNFT.CollectionPublicPath)
    .check()
}
