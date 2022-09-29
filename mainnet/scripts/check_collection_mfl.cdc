import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448
import MFLPlayer from 0x8ebcbfd516b1da27

pub fun main(address: Address): Bool {
  return getAccount(address)
    .getCapability<&MFLPlayer.Collection{NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection}>(MFLPlayer.CollectionPublicPath)
    .check()
}
