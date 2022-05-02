// SPDX-License-Identifier: UNLICENSED

/*

  GaiaNFT

  This contract encompasses the minting and related administration logic for
  NFTs hosted by Gaia (https://ongaia.com/).

  NFTs are minted with references to Template structs. Templates allow a
  GaiaNFT Admin to reveal the NFT metadata after it has been minted (and 
  probably bought). In order to assure collectors that the metadata was
  decided pre-mint and not changed before reveal, Admins must mint metadata
  with a fixed sized byte array checksum. The revealed metadata should
  provide a unique hash (by implementing the {GaiaMetadata} interface) that
  can be used to verify the checksum.

  This setup allows for any custom structs to act as metadata for the NFT, 
  as long as they implement GaiaMetadata to 
  - allow checksum reveals
  - allow third party services to rely on well-known metadata standards to 
    properly view the NFT.
  - provide a standard Display interface for wallets
  - provide a {string: string} representation of the metadata for reporting

  Gaia admins may want to "drop" multiple NFTs all at the same time. This
  can be coordinated with Set resources, defined in this contract. Sets must
  be configured with a list of Templates from which to mint NFTs with. No NFTs
  can be minted until the Set is Locked, and only those NFTs which were
  specified pre-lock are allowed to be minted from that Set. Using SetManager
  resources, Admins can issue modification privileges for each set individually.

  The general workflow would look as follows.
  1.  This contract is deployed with a singleton Admin resource
  2.  The Admin creates as many Sets as needed
  3.  Accounts responsible for managing sets initialze a GaiaAccount resource 
      so they may accept SetManager privileges
  4.  The Admin creates SetManager resources (at least one per Set) and
      distributes them to the appropriate GaiaAccounts
  5.  For each independent Set, A SetManager configures the Set with Templates
  6.  A SetManager locks the Set as a commitment to limit the drop to the 
      configured Templates
  7.  A SetManager mints NFTs to any account's collection they choose.
  8.  A Set is marked as Completed once all NFTs have been minted from that Set

 */

import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448
import Crypto

pub contract GaiaNFT: NonFungibleToken {

  // Events
  //
  // This contract is initialized
  pub event ContractInitialized()

  // NFT is minted
  pub event NFTMinted(
    nftId: UInt64,
    setId: UInt64,
    templateId: UInt64,
    displayName: String,
    displayDescription: String,
    displayURI: String,
    creator: Address,
  )

  // NFT is withdrawn from a collection
  pub event Withdraw(id: UInt64, from: Address?)

  // NFT is deposited from a collection
  pub event Deposit(id: UInt64, to: Address?)

  // NFT is destroyed
  pub event NFTDestroyed(id: UInt64)

  // NFT template metadata is revealed
  pub event NFTRevealed(
    nftId: UInt64,
    setId: UInt64,
    templateId: UInt64,
    displayName: String,
    displayDescription: String,
    displayURI: String,
    metadata: {String: String},
    templateType: Type
  )

  // Set has been created
  pub event SetCreated(setId: UInt64, name: String)

  // Set has been marked Locked
  pub event SetLocked(setId: UInt64, numTemplates: UInt64)

  // Set has started Minting
  pub event SetMinting(setId: UInt64)

  // Set has finished Minting and is now in the Complete stage
  pub event SetComplete(setId: UInt64)

  // SetManager created
  pub event SetManagerCreated(
    setManagerId: UInt64,
    setId: UInt64,
    role: UInt8
  )

  // SetManager assigned
  pub event SetManagerAssigned(
    setManagerId: UInt64,
    setId: UInt64,
    account: Address?
  )

  // SetManager removed
  pub event SetManagerRemoved(
    setManagerId: UInt64,
    setId: UInt64,
    account: Address?
  )

  // SetManager revoked
  pub event SetManagerRevoked(
    setManagerId: UInt64
  )

  // SetManager unrevoked
  pub event SetManagerUnrevoked(
    setManagerId: UInt64
  )

  // Paths
  //
  pub let CollectionStoragePath: StoragePath
  pub let CollectionPublicPath: PublicPath 
  pub let CollectionPrivatePath: PrivatePath
  pub let AdminStoragePath: StoragePath
  pub let GaiaAccountPublicPath: PublicPath
  pub let GaiaAccountPath: StoragePath

  // Total NFT supply
  pub var totalSupply: UInt64

  // Dictionary mapping from set IDs to Set resources
  access(self) var sets: @{UInt64: Set}
  
  // Total number of SetManager resources created
  pub var setManagerSupply: UInt64

  // Revoked SetManager ids
  pub var setManagerRevocations: {UInt64: Bool}

  // All GaiaNFT metadata can have custom definitions but must have the
  // following implemented in order to power all the features of the
  // Gaia NFT contract.
  pub struct interface GaiaMetadata {

    // Hash representation of implementing structs.
    pub fun hash(): [UInt8]

    // Representative Display
    pub fun display(): MetadataViews.Display

    // Representative {string: string} serialization
    pub fun repr(): {String: String}
    
    // MetadataViews compliant
    pub fun getViews(): [Type]
    pub fun resolveView(_ view: Type): AnyStruct?
  }

  // NFT
  //
  // Gaia NFTs are "standard" NFTs that implement MetadataViews and point
  // to a Template struct that give information about the NFTs metadata
  pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {

    // id is unique among all Gaia NFTs on Flow, ordered sequentially from 0
    pub let id: UInt64

    // setID and templateID help us locate the specific template in the
    // specific set which stores this NFTs metadata
    pub let setId: UInt64
    pub let templateId: UInt64

    // The creator of the NFT
    pub let creator: Address

    // Fetch the metadata Template represented by this NFT
    pub fun template(): {TemplateNFT} {
      return GaiaNFT.getTemplate(setId: self.setId, templateId: self.templateId)
    }

    // Proxy for MetadataViews.Resolver.getViews implemented by Template
    pub fun getViews(): [Type] {
      let template = self.template()
      return template.getViews()
    }

    // Proxy for MetadataViews.Resolver.resolveView implemented by Template
    pub fun resolveView(_ view: Type): AnyStruct? {
      let template = self.template()
      return template.resolveView(view)
    }

    // NFT needs to be told which Template it follows
    init(setId: UInt64, templateId: UInt64, creator: Address) {
      self.id = GaiaNFT.totalSupply
      GaiaNFT.totalSupply = GaiaNFT.totalSupply + 1
      self.setId = setId
      self.templateId = templateId
      self.creator = creator
      let defaultDisplay = self.template().defaultDisplay
      emit NFTMinted(
        nftId: self.id,
        setId: self.setId,
        templateId: self.templateId,
        displayName: defaultDisplay.name,
        displayDescription: defaultDisplay.description,
        displayURI: defaultDisplay.thumbnail.uri(),
        creator: self.creator
      )
    }

    // Emit NFTDestroyed when destroyed
    destroy() {
      emit NFTDestroyed(
        id: self.id,
      )
    }
  }

  // Collection
  //
  // Collections provide a way for collectors to store Gaia NFTs in their
  // Flow account. 

  // Exposing this interface allows external parties to inspect a Flow
  // account's GaiaNFT Collection and deposit NFTs
  pub resource interface CollectionPublic {
    pub fun deposit(token: @NonFungibleToken.NFT)
    pub fun getIDs(): [UInt64]
    pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
    pub fun borrowGaiaNFT(id: UInt64): &NFT
  }

  pub resource Collection: CollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {

    // NFTs are indexed by its globally assigned id
    pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

    // Deposit a GaiaNFT into the collection. Safe to assume id's are unique.
    pub fun deposit(token: @NonFungibleToken.NFT) {
      // Required to ensure this is a GaiaNFT
      let token <- token as! @GaiaNFT.NFT
      let id: UInt64 = token.id
      let oldToken <- self.ownedNFTs[id] <- token
      emit Deposit(id: id, to: self.owner?.address)
      destroy oldToken
    }

    // Withdraw an NFT from the collection.
    // Panics if NFT does not exist in the collection
    pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
      pre {
        self.ownedNFTs.containsKey(withdrawID)
          : "NFT does not exist in collection."
      }
      let token <- self.ownedNFTs.remove(key: withdrawID)!
      emit Withdraw(id: token.id, from: self.owner?.address)
      return <-token
    }

    // Return all the IDs from the collection.
    pub fun getIDs(): [UInt64] {
      return self.ownedNFTs.keys
    }

    // Borrow a reference to the specified NFT
    // Panics if NFT does not exist in the collection
    pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
      pre {
        self.ownedNFTs.containsKey(id)
          : "NFT does not exist in collection."
      }
      return &self.ownedNFTs[id] as &NonFungibleToken.NFT
    }

    // Borrow a reference to the specified NFT as a Gaia NFT.
    // Panics if NFT does not exist in the collection
    pub fun borrowGaiaNFT(id: UInt64): &NFT {
      pre {
        self.ownedNFTs.containsKey(id)
          : "NFT does not exist in collection."
      }
      let ref = &self.ownedNFTs[id] as auth &NonFungibleToken.NFT
      return ref as! &NFT
    }

    // Return the MetadataViews.Resolver of the specified NFT
    // Panics if NFT does not exist in the collection
    pub fun borrowViewResolver(id: UInt64): &{MetadataViews.Resolver} {
      pre {
        self.ownedNFTs.containsKey(id)
          : "NFT does not exist in collection."
      }
      let nft = &self.ownedNFTs[id] as auth &NonFungibleToken.NFT
      let gaiaNft = nft as! &NFT
      return gaiaNft
    }

    init() {
      self.ownedNFTs <- {}
    }

    // If the collection is destroyed, destroy the NFTs it holds, as well
    destroy() {
      destroy self.ownedNFTs
    }
  }

  // Anyone can make and store collections
  pub fun createEmptyCollection(): @Collection {
    return <-create Collection()
  }

  // Set
  //
  // Sets are ultimately the things that construct the NFTs. In other words,
  // all NFTs must be minted as part of a set. 
  //
  // Sets also use Templates to allow creators to commit to group of NFTs
  // at once. After the Set has been configured with NFTs, the admin must lock
  // the set, disallowing any new templates to be added to the set. NFTs can 
  // only be minted after an admin has locked a set. This can help creators
  // provide guarantees about the scarcity of a set.
  //
  // You can generally expect Sets to have 1-1 correlations with "drops"

  // Set statuses
  pub enum Status: UInt8 {

    // Sets start off as Open, which means Templates can still be configured
    pub case Open

    // Admins must lock Sets after configuring the Templates. Templates can
    // no longer be configured at this state. The set can now start minting.
    // Note that we cannot go straight from Open to Minting
    pub case Locked

    // The set has already minted at least one NFT and still has NFTs left to
    // mint.
    pub case Minting

    // The Set has completed minting all of its NFTs
    pub case Complete
  }

  pub resource Set {

    // Globally assigned id based on number of created Sets.
    pub let id: UInt64

    // Current status of Set
    pub var status: Status

    // Metadata for the Set
    pub var metadata: SetMetadata

    // Templates configured to be minted from this Set
    access(contract) var templates: [Template]

    // Number of NFTs that have minted from this Set
    pub var minted: UInt64

    // Add a new Template to the Set, only if the Set is Open
    pub fun addTemplate(template: Template) {
      pre {
        self.status == Status.Open : "Set is not Open. It cannot be modified"
      }
      self.templates.append(template)
    }

    // Clear the configured Templates from this Set if the Set is still Open.
    // This is here in case any mistakes were made and the creator needs to
    // start over
    pub fun clearTemplates() {
      pre {
        self.status == Status.Open : "Set is not Open. It cannot be modified"
      }
      self.templates = []
    }

    // Lock the Set if it is Open. This signals that this Set
    // will mint NFTs based only on the Templates configured in this Set.
    pub fun lock() {
      pre {
        self.status == Status.Open : "Only an Open set can be locked."
        self.templates.length > 0
          : "Set must be configured with at least one Template."
      }
      self.status = Status.Locked
      emit SetLocked(setId: self.id, numTemplates: UInt64(self.templates.length))
    }

    // Mint numToMint NFTs with the supplied creator attribute. The NFT will
    // be minted into the provided receiver
    pub fun mint(
      templateId: UInt64,
      creator: Address,
      receiver: &{NonFungibleToken.CollectionPublic}) 
    {
      pre {
        self.status != Status.Open
          : "Set must be locked before it can start minting."
        self.status != Status.Complete
          : "Set has already completed minting."
        templateId < UInt64(self.templates.length)
          : "templateId does not exist in Set."
        self.templates[templateId].mintID == nil
          : "Template has already been marked as minted."
      }
      if (self.status == Status.Locked) {
        self.status = Status.Minting
        emit SetMinting(setId: self.id)
      }
      let nft <-create NFT(
          setId: self.id,
          templateId: templateId,
          creator: creator
        )
      self.templates[templateId].markMinted(nftId: nft.id)
      receiver.deposit(
        token: <-nft
      )
      self.minted = self.minted + 1
      if (self.minted == UInt64(self.templates.length)) {
        self.status = Status.Complete
        emit SetComplete(setId: self.id)
      }
    }

    // Reveal a specified Template in a Set.
    pub fun revealTemplate(
      templateId: UInt64,
      metadata: {GaiaMetadata},
      salt: [UInt8]
    ) {
      pre {
        templateId < UInt64(self.templates.length)
          : "templateId does not exist in Set."
        self.templates[templateId].mintID != nil
          : "Template has already been marked as minted."
      }
      let template = &self.templates[templateId] as &Template
      template.reveal(metadata: metadata, salt: salt)

      let display = metadata.display()
      emit NFTRevealed(
        nftId: template.mintID!,
        setId: self.id,
        templateId: templateId,
        displayName: display.name,
        displayDescription: display.description,
        displayURI: display.thumbnail.uri(),
        metadata: metadata.repr(),
        templateType: template.metadata.getType()
      )
    }

    init(id: UInt64, metadata: SetMetadata) {
      self.id = id
      self.metadata = metadata

      self.status = Status.Open
      self.templates = []

      self.minted = 0
      emit SetCreated(setId: id, name: metadata.name)
    }
  }

  // Create and store a new Set. Return the id of the new Set.
  access(contract) fun createSet(metadata: SetMetadata): UInt64 {
    let newSet <- create Set(
      id: UInt64(GaiaNFT.sets.length),
      metadata: metadata
    )
    let setId = newSet.id
    GaiaNFT.sets[setId] <-! newSet
    return setId
  }

  // Number of sets created by contract
  pub fun setsCount(): Int{
    return GaiaNFT.sets.length
  }

  // Metadata for the Set
  pub struct SetMetadata {
    pub var name: String
    pub var description: String
    init(name: String, description: String) {
      self.name = name
      self.description = description
    }
  }

  // A summary report of a Set
  pub struct SetReport {
    pub let id: UInt64
    pub let status: Status
    pub let metadata: SetMetadata
    pub let numTemplates: Int
    pub let numMinted: UInt64
    init(
      id: UInt64,
      status: Status,
      metadata: SetMetadata,
      numTemplates: Int,
      numMinted: UInt64
    ) {
      self.id = id
      self.status = status
      self.metadata = metadata
      self.numTemplates = numTemplates
      self.numMinted = numMinted
    }
  }

  // Generate a SetReport for informational purposes (to be used with scripts)
  pub fun generateSetReport(setId: UInt64): SetReport {
    let setRef = &self.sets[setId] as &Set
    return SetReport(
      id: setId,
      status: setRef.status,
      metadata: setRef.metadata,
      numTemplates: setRef.templates.length,
      numMinted: setRef.minted
    )
  }

  // Template
  //
  // Templates are mechanisms for handling NFT metadata. These should ideally
  // have a one to one mapping with NFTs, with the assumption that NFTs are 
  // designed to be unique. Template allows the creator to commit to an NFTs
  // metadata without having to reveal the metadata itself. The constructor
  // accepts a byte array checksum. After construction, anyone with access
  // to this struct will be able to reveal the metadata, which must be any
  // struct which implements GaiaMetadata and MetadataViews.Resolver such that
  // SHA3_256(salt || metadata.hash()) == checksum.
  //
  // Templates can be seen as metadata managers for NFTs. As such, Templates
  // also implement the MetadataResolver interface to conform with standards.

  // Safe Template interface for anyone inspecting NFTs
  pub struct interface TemplateNFT {
    pub let defaultDisplay: MetadataViews.Display
    pub var metadata: {GaiaMetadata}?
    pub var mintID: UInt64?
    pub fun checksum(): [UInt8]
    pub fun salt(): [UInt8]?
    pub fun revealed(): Bool
    pub fun getViews(): [Type]
    pub fun resolveView(_ view: Type): AnyStruct?
  }

  pub struct Template: TemplateNFT {

    // checksum as described above
    access(self) let _checksum: [UInt8]

    // Default Display in case the Template has not yet been revealed
    pub let defaultDisplay: MetadataViews.Display

    // salt and metadata are optional so they can be revealed later, such that
    // SHA3_256(salt || metadata.hash()) == checksum
    access(self) var _salt: [UInt8]?
    pub var metadata: {GaiaMetadata}?

    // Convenience attribute to mark whether or not Template has minted NFT
    pub var mintID: UInt64?

    // Helper function to check if a proposed metadata and salt reveal would
    // produce the configured checksum in a Template
    pub fun validate(metadata: {GaiaMetadata}, salt: [UInt8]): Bool {
      let hash = String.encodeHex(
        HashAlgorithm.SHA3_256.hash(
          salt.concat(metadata.hash())
        )
      )
      let checksum = String.encodeHex(self.checksum())
      return hash == checksum
    }

    // Reveal template metadata and salt. validate() is called as a precondition
    // so collector can be assured metadata was not changed
    pub fun reveal(metadata: AnyStruct{GaiaMetadata}, salt: [UInt8]) {
      pre {
        self.mintID != nil
          : "Template has not yet been minted."
        !self.revealed()
          : "NFT Template has already been revealed"
        self.validate(metadata: metadata, salt: salt)
          : "salt || metadata.hash() does not hash to checksum"
      }
      self.metadata = metadata
      self._salt = salt
    }

    pub fun checksum(): [UInt8] {
      return self._checksum
    }

    pub fun salt(): [UInt8]? {
      return self._salt
    }

    // Check to see if metadata has been revealed
    pub fun revealed(): Bool {
      return self.metadata != nil
    }

    // Mark the NFT as minted
    pub fun markMinted(nftId: UInt64) {
      self.mintID = nftId
    }

    // Implements MetadataResolver.getViews
    pub fun getViews(): [Type] {
      if (!self.revealed()) {
        return [Type<MetadataViews.Display>()]
      }
      return self.metadata!.getViews()
    }

    // Implements MetadataResolver.resolveView
    pub fun resolveView(_ view: Type): AnyStruct? {
      if (!self.revealed()) {
        if (view != Type<MetadataViews.Display>()) {
          return nil
        }
        return self.defaultDisplay
      }
      return self.metadata!.resolveView(view)
    }

    init(checksum: [UInt8], defaultDisplay: MetadataViews.Display) {
      self._checksum = checksum
      self.defaultDisplay = defaultDisplay

      self._salt = nil
      self.metadata = nil
      self.mintID = nil
    }
  }

  // Public helper function to be able to inspect any Template
  pub fun getTemplate(setId: UInt64, templateId: UInt64): {TemplateNFT} {
    let setRef = &self.sets[setId] as &Set
    return setRef.templates[templateId]
  }

  // GaiaAccount
  //
  // It is expected that some accounts will be managing multiple Sets. Because
  // a SetManager gives authority over a single Set, GaiaAccount was created to 
  // allow an account to organize multiple SetManager resources. A GaiaAccount
  // can only store one SetManager per Set

  // Anyone is technically allowed to add SetManager resources to a GaiaAccount,
  // but only an Admin is allowed to create and assign SetManagers.
  pub resource interface GaiaAccountPublic {
    pub fun addSetManager(setManager: @SetManager)
    pub fun getSetManagersCount(): Int
  }

  pub resource GaiaAccount: GaiaAccountPublic {

    // SetId: SetManager
    access(self) let setManagers: @{UInt64: SetManager} 

    // Add a SetManager and index it by the setId. Panic if we already have
    // a SetManager for that setId.
    pub fun addSetManager(setManager: @SetManager) {
      pre {
        !self.setManagers.containsKey(setManager.setId)
          : "Cannot add SetManager: SetNanager already exists for this set."
      }
      let setManagerId = setManager.id
      let setId = setManager.setId
      let oldSm <- self.setManagers.insert(key: setId, <- setManager)
      destroy oldSm
      emit SetManagerAssigned(
        setManagerId: setManagerId,
        setId: setId,
        account: self.owner?.address
      )
    }

    // Get number of SetManagers in account
    pub fun getSetManagersCount(): Int {
      return self.setManagers.length
    }

    // Borrow the SetManager for the specified Set if it exists.
    pub fun borrowSetManager(setId: UInt64): &SetManager {
      pre {
        self.setManagers.containsKey(setId)
          : "GaiaAccount does not contain a SetManager for the provided setId."
      }
      let setManagerRef = &self.setManagers[setId] as &GaiaNFT.SetManager
      return setManagerRef
    }
    
    // We do not want to allow anyone to overwrite SetManagers using the
    // public addSetManager function. Therefore, a SetManager will
    // have to be removed before it can be replaced with a modified
    // SetManager token (if desired by the GaiaAccount owner)
    pub fun removeSetManager(setId: UInt64) {
      pre {
        self.setManagers.containsKey(setId)
          : "Cannot remove SetManager: SetManager does not exist for this set."
      }
      let setManager <- self.setManagers.remove(key: setId)!
      emit SetManagerRemoved(
        setManagerId: setManager.id,
        setId: setId,
        account: self.owner?.address
      )
      destroy setManager
    }

    init() {
      self.setManagers <- {}
    }

    destroy() {
      destroy self.setManagers
    }
  }

  // Exposed function to create a GaiaAccount
  pub fun createGaiaAccount(): @GaiaAccount {
    return <-create GaiaAccount()
  }

  // Predefined Set Manager Roles
  pub enum SetManagerRole: UInt8 {

    // Create templates, NFTs, and new Set Managers.
    pub case Super     

    // Create templates, NFTs.
    pub case Operator  
  }

  // Set Managers 
  // Create Templates and mint NFTs from them
  //
  pub resource SetManager {
    pub let id: UInt64
    pub let setId: UInt64
    pub let role: SetManagerRole

    // Get reference to the Set made accessible to this SetManager
    pub fun getSet(): &Set {
      pre {
        !self.revoked(): "SetManager Token has been revoked."
      }
      return &GaiaNFT.sets[self.setId] as &Set
    }

    // Super SetManagers can create new SetManagers
    pub fun createSetManager(role: SetManagerRole): @SetManager {
      pre {
        !self.revoked(): "SetManager Token has been revoked."
        self.role == SetManagerRole.Super
          : "Cannot create new Set Manager: Needs Super privileges"
      }
      return <- create SetManager(setId: self.setId, role: role)
    }

    // Helper function to test if SetManager token has been revoked by Admin
    pub fun revoked(): Bool {
        return GaiaNFT.setManagerRevocations.containsKey(self.id)
    }

    init(
      setId: UInt64, 
      role: SetManagerRole
    ){
      self.id = GaiaNFT.setManagerSupply
      GaiaNFT.setManagerSupply = GaiaNFT.setManagerSupply + 1
      self.setId = setId
      self.role = role
      emit SetManagerCreated(
        setManagerId: self.id,
        setId: self.setId,
        role: self.role.rawValue
      )
    }
  }

  // Admin
  //
  // The Admin is meant to be a singleton superuser of the contract. The Admin
  // is responsible for creating Sets and SetManagers for managing the sets.
  pub resource Admin {

    // Create a set with the provided SetMetadata.
    pub fun createSet(metadata: SetMetadata) {
      GaiaNFT.createSet(metadata: metadata)
    }

    // Create a SetManager for any preexisting Set
    pub fun createSetManager(setId: UInt64, role: SetManagerRole): @SetManager {
      pre {
        GaiaNFT.sets[setId] != nil
          : "Cannot create Set Manager: Set doesn't exist"
      }
      return <- create SetManager(setId: setId, role: role)
    }

    // Revoke a SetManager's Set modification privileges.
    pub fun revokeSetManager(setManagerId: UInt64) {
      pre {
        setManagerId < GaiaNFT.setManagerSupply
          : "Provided setManagerId does not exist."
      }
      GaiaNFT.setManagerRevocations[setManagerId] = true
      emit SetManagerRevoked(
        setManagerId: setManagerId
      )
    }

    // Unrevoke a SetManager's Set modification privileges.
    pub fun unrevokeSetManager(setManagerId: UInt64) {
      pre {
        GaiaNFT.setManagerRevocations.containsKey(setManagerId)
          : "SetManager privilege is not currently revoked."
      }
      GaiaNFT.setManagerRevocations.remove(key: setManagerId)
      emit SetManagerUnrevoked(
        setManagerId: setManagerId
      )
    }
  }

  // Contract constructor
  init() {

    // Collection Paths
    self.CollectionStoragePath = /storage/GaiaCollection
    self.CollectionPublicPath = /public/GaiaCollection
    self.CollectionPrivatePath = /private/GaiaCollection

    // GaiaAccount Paths
    self.GaiaAccountPublicPath = /public/GaiaAccountPublic
    self.GaiaAccountPath = /storage/GaiaAccount

    // Admin Storage Path. Save the singleton Admin resource to contract
    // storage.
    self.AdminStoragePath = /storage/GaiaAdmin
    self.account.save<@Admin>(<- create Admin(), to: self.AdminStoragePath)
    
    // Initializations
    self.totalSupply = 0
    self.sets <- {}
    self.setManagerSupply = 0
    self.setManagerRevocations = {}

    emit ContractInitialized()
  }
}