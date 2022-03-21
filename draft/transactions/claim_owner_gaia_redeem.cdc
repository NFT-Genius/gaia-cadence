import NonFungibleToken from 0xNonFungibleToken
import ClaimNFT from 0xClaimNFT
import IClaimNFT from 0xIClaimNFT
import ClaimNFTRedeemer from 0xClaimNFTRedeemer
import Gaia from 0xGaia

// Claim owner redeems Gaia Claim for their associated NFTs in escrow.

transaction(id: UInt64, redeemerAddress: Address){
    let claim: @ClaimNFT.NFT
    let redeemer: &{ClaimNFTRedeemer.RedeemerPublic}
    let nftCollection: &{NonFungibleToken.CollectionPublic}

    prepare(signer: AuthAccount) {
        // Gaia NFT Collection init
        if signer.borrow<&Gaia.Collection>(from: Gaia.CollectionStoragePath) == nil {
            let collection <- Gaia.createEmptyCollection() as! @Gaia.Collection
            signer.save(<-collection, to: Gaia.CollectionStoragePath)
            signer.link<&{NonFungibleToken.CollectionPublic, Gaia.CollectionPublic}>(Gaia.CollectionPublicPath, target: Gaia.CollectionStoragePath)
        }
        self.nftCollection = signer.getCapability<&{NonFungibleToken.CollectionPublic}>(Gaia.CollectionPublicPath).borrow()
            ?? panic("could not borrow nft collection")

        let claimCollection = signer.getCapability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>(ClaimNFT.CollectionPrivatePath).borrow()
            ?? panic("could not borrow claim collection")
        self.claim <- claimCollection.withdraw(withdrawID: id) as! @ClaimNFT.NFT

        self.redeemer = getAccount(redeemerAddress).getCapability<&{ClaimNFTRedeemer.RedeemerPublic}>(ClaimNFTRedeemer.RedeemerPublicPath).borrow()
            ?? panic("could not borrow redeemer")
    }
    
    execute {
        let nfts <- self.redeemer.redeemClaim(claimNFT: <- self.claim)
        var i = 0
        while i < nfts.length {
            let nft <- nfts.remove(at: 0)
            self.nftCollection.deposit(token: <- nft)
        }
        assert(nfts.length == 0, message: "nft(s) weren't deposited into collection")
        destroy nfts
    }
}