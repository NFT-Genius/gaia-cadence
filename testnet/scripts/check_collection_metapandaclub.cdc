import MetaPanda from 0x26e7006d6734ba69
import NonFungibleToken from 0x631e88ae7f1d7c20

pub fun main(address: Address): Bool {
  return getAccount(address)
    .getCapability<&{NonFungibleToken.CollectionPublic}>(MetaPanda.CollectionPublicPath)
    .check()
}
