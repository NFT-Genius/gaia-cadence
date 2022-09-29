import NonFungibleToken from 0x631e88ae7f1d7c20
import BarterYardClubWerewolf from 0x195caada038c5806

pub fun main(address: Address): Bool {
  return getAccount(address)
    .getCapability<&BarterYardClubWerewolf.Collection{NonFungibleToken.CollectionPublic}>(BarterYardClubWerewolf.CollectionPublicPath)
    .check()
}
