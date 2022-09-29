import NonFungibleToken from 0x631e88ae7f1d7c20
import MetadataViews from 0x631e88ae7f1d7c20
import CryptoPiggo from 0x57e1b27618c5bb69

pub fun main(address: Address): Bool {
  return getAccount(address)
    .getCapability<&CryptoPiggo.Collection{CryptoPiggo.CryptoPiggoCollectionPublic, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection}>(CryptoPiggo.CollectionPublicPath)
    .check()
}
