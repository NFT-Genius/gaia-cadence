import DugoutDawgzNFT from 0xd527bd7a74847cc7

pub fun main(address: Address): Bool {
  return getAccount(address)
    .getCapability<&{DugoutDawgzNFT.CollectionPublic}>(DugoutDawgzNFT.CollectionPublicPath)
    .check()
}
