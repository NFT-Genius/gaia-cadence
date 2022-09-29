import DriverzNFT from 0xa039bd7d55a96c0c
import NonFungibleToken from 0x1d7e57aa55817448

pub fun main(address: Address): Bool {
  return getAccount(address)
    .getCapability<&{DriverzNFT.CollectionPublic}>(DriverzNFT.CollectionPublicPath)
    .check()
}
