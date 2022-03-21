import ClaimNFT from 0xClaimNFT
import IClaimNFT from 0xIClaimNFT
import ClaimNFTRedeemer from 0xClaimNFTRedeemer

// Claim admin reveals claim metadata.

transaction(
    id: UInt64, 
    nftContractAddrs: [Address], 
    nftContractNames: [String],
    nftDeclarationNames: [String],
    nftIDs: [UInt64],
    salt: String
){
    let admin: &{IClaimNFT.IAdmin}

    prepare(signer: AuthAccount) {
        self.admin = signer.getCapability(ClaimNFT.AdminPrivatePath)!.borrow<&ClaimNFT.Admin{IClaimNFT.IAdmin}>()
            ?? panic("Could not borrow Admin resource")

        assert(
            nftContractAddrs.length == nftContractNames.length &&
            nftContractAddrs.length == nftDeclarationNames.length &&
            nftContractAddrs.length == nftIDs.length,
            message: "data length mismatch"
        )
    }

    execute {
        let fqtns: [ClaimNFTRedeemer.FQTN] = []
        var i = 0
        while i < nftContractAddrs.length {
           let fqtn = ClaimNFTRedeemer.FQTN(
               address: nftContractAddrs[i], 
               contractName: nftContractNames[i],
               declarationName: nftDeclarationNames[i], 
               id: nftIDs[i]
            )
            fqtns.append(fqtn)
            i = i + 1
        }

        self.admin.revealClaim(id: id, metadata: fqtns, salt: salt)
    }
}