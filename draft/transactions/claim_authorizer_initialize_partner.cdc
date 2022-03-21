import NonFungibleToken from 0xNonFungibleToken
import Gaia from 0xGaia
import ClaimNFT from 0xClaimNFT
import IClaimNFT from 0xIClaimNFT

// ClaimNFT admin Initializes a partner account with the required resources to orchestrate a drop.

transaction {
    let partnerAddress: Address

    prepare(partner: AuthAccount, admin: AuthAccount) {
        self.partnerAddress = partner.address

        // Gaia Collection init
        if partner.borrow<&Gaia.Collection>(from: Gaia.CollectionStoragePath) == nil {
            let collection <- Gaia.createEmptyCollection() as! @Gaia.Collection
            partner.save(<-collection, to: Gaia.CollectionStoragePath)
            partner.link<&{NonFungibleToken.CollectionPublic, Gaia.CollectionPublic}>(Gaia.CollectionPublicPath, target: Gaia.CollectionStoragePath)
        }

        // Claim NFT Admin init
        if partner.getCapability(ClaimNFT.AdminPrivatePath).borrow<&{IClaimNFT.IAdmin}>() == nil {
            let a = admin.borrow<&ClaimNFT.Authorizer>(from: ClaimNFT.AuthorizerStoragePath)
                ?? panic("cannot borrow Admin resource from Admin Account") 
            let adminResouce <- a.createNewAdmin() as! @ClaimNFT.Admin
            partner.save(<-adminResouce, to: ClaimNFT.AdminStoragePath) 
            partner.link<&ClaimNFT.Admin{IClaimNFT.IAdmin}>(ClaimNFT.AdminPrivatePath, target: ClaimNFT.AdminStoragePath)
        }

        // Claim Collection init
        if partner.getCapability(ClaimNFT.CollectionPublicPath).borrow<&{NonFungibleToken.CollectionPublic}>() == nil {
            let collection <- ClaimNFT.createEmptyCollection()
            partner.save(<- collection, to: ClaimNFT.CollectionStoragePath)
            partner.link<&ClaimNFT.Collection{NonFungibleToken.CollectionPublic}>(ClaimNFT.CollectionPublicPath, target: ClaimNFT.CollectionStoragePath)
            partner.link<&ClaimNFT.Collection{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>(ClaimNFT.CollectionPrivatePath, target: ClaimNFT.CollectionStoragePath)
            partner.link<&ClaimNFT.Collection{IClaimNFT.IClaimNFTCollectionPublic}>(ClaimNFT.IClaimNFTCollectionPublicPath, target: ClaimNFT.CollectionStoragePath)
        }
    }
}