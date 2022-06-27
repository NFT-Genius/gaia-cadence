import NonFungibleToken from 0x1d7e57aa55817448
import NFTStorefront from 0x4eb8a10cb9f87357
import MetadataViews from 0x1d7e57aa55817448
import BarterYardClubWerewolf from 0x28abb9f291cadaf2

pub struct PurchaseData {
    pub let id: UInt64
    pub let name: String?
    pub let amount: UFix64
    pub let description: String?
    pub let imageURL: String?

    init(id: UInt64, name: String?, amount: UFix64, description: String?, imageURL: String?) {
        self.id = id
        self.name = name
        self.amount = amount
        self.description = description
        self.imageURL = imageURL
    }
}

pub fun main(merchantAddress: Address, listingResourceID: UInt64, ownerAddress: Address, expectedPrice: UFix64, signatureExpiration: UInt64, signature: String): PurchaseData {
    let account = getAccount(ownerAddress)
    let marketCollectionRef = account
        .getCapability<&NFTStorefront.Storefront{NFTStorefront.StorefrontPublic}>(
            NFTStorefront.StorefrontPublicPath
        )
        .borrow()
        ?? panic("Could not borrow market collection from address")

    let saleItem = marketCollectionRef.borrowListing(listingResourceID: listingResourceID)
        ?? panic("No item with that ID")

    let listingDetails = saleItem.getDetails()!

    let collection = account.getCapability(BarterYardClubWerewolf.CollectionPublicPath)
        .borrow<&{MetadataViews.ResolverCollection}>()
        ?? panic("Could not borrow a reference to the collection")

    let resolver = collection!.borrowViewResolver(id: listingDetails.nftID)

    let view = resolver.resolveView(Type<MetadataViews.Display>())
        ?? panic("Could not resolve view")

    let display = view as! MetadataViews.Display

    var imageURI = display.thumbnail.uri()
    if (imageURI.slice(from: 0, upTo: 7) == "ipfs://") {
        imageURI = "https://images.ongaia.com/ipfs/".concat(imageURI.slice(from: 7, upTo: imageURI.length))
    }

    let purchaseData = PurchaseData(
        id: listingDetails.nftID,
        name: display.name,
        amount: listingDetails.salePrice,
        description: display.description,
        imageURL: imageURI,
    )

    return purchaseData
}
