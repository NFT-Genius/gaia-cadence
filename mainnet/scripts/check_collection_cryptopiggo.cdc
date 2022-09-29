import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448
import CryptoPiggo from 0xd3df824bf81910a4

pub fun main(address: Address): Bool {
  return getAccount(address)
    .getCapability<&CryptoPiggo.Collection{CryptoPiggo.CryptoPiggoCollectionPublic, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection}>(CryptoPiggo.CollectionPublicPath)
    .check()
}
