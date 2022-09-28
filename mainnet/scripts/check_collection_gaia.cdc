import Gaia from 0x8b148183c28ff88f

pub fun main(address: Address): Bool {
  return getAccount(address)
    .getCapability<&{Gaia.CollectionPublic}>(Gaia.CollectionPublicPath)
    .check()
}
