import DriverzNFT from 0xf44b704689c35798

pub fun main(address: Address): Bool {
  return getAccount(address)
    .getCapability<&{DriverzNFT.CollectionPublic}>(DriverzNFT.CollectionPublicPath)
    .check()
}
