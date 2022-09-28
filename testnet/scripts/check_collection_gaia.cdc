import Gaia from 0x40e47dca6a761db7

pub fun main(address: Address): Bool {
  return getAccount(address)
    .getCapability<&{Gaia.CollectionPublic}>(Gaia.CollectionPublicPath)
    .check()
}
