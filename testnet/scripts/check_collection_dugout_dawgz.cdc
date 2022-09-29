import DugoutDawgzNFT from 0x44eb6c679f0a4adc

pub fun main(address: Address): Bool {
  return getAccount(address)
    .getCapability<&{DugoutDawgzNFT.CollectionPublic}>(DugoutDawgzNFT.CollectionPublicPath)
    .check()
}
