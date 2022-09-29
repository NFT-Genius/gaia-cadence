import NonFungibleToken from 0x1d7e57aa55817448
import BarterYardClubWerewolf from 0x28abb9f291cadaf2

pub fun main(address: Address): Bool {
  return getAccount(address)
    .getCapability<&BarterYardClubWerewolf.Collection{NonFungibleToken.CollectionPublic}>(BarterYardClubWerewolf.CollectionPublicPath)
    .check()
}
