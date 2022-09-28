import NonFungibleToken from 0x1d7e57aa55817448
import MetaPanda from 0xf2af175e411dfff8

pub fun main(address: Address): Bool {
  return getAccount(address)
    .getCapability<&{NonFungibleToken.CollectionPublic}>(MetaPanda.CollectionPublicPath)
    .check()
}
