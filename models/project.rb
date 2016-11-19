# Copyright 2012 Team 254. All Rights Reserved.
# @author pat@patfairbank.com (Patrick Fairbank)
#
# Represents a grouping of related parts, such as a certain robot.

class Project < Sequel::Model
  one_to_many :parts
  one_to_many :orders

  def onshape_update_settings(params)
    if params[:onshape_enable]
      self.onshape_top_document = params[:onshape_top_document]
      self.onshape_top_element = params[:onshape_top_element]

      # Validate
      document = params[:onshape_top_document]
      element = params[:onshape_top_element]
      workspace = onshape_mainworkspace(document)
      res = onshape_request('/api/assemblies/d/'+document+'/w/'+workspace+'/e/'+element)
    
    else
      self.onshape_top_document = nil
      self.onshape_top_element = nil
    end
  end

  def onshape_update_tree()
    raise "Not an Onshape Assembly" unless self[:onshape_top_document]

    DB.transaction do

    # Delete Non-CP Parts
    Part.where(:project_id => self.id, :part_number => nil).delete

    # Clear Onshape Metadata
    Part.where(:project_id => self.id).update(
      :quantity => 0,
      :onshape_document => nil,
      :onshape_element => nil,
      :onshape_workspace => nil,
      :onshape_part => nil,
      :onshape_microversion => nil)

    # Get Top Level Assembly
    tla = Part[:part_number => 0, :project_id => self.id]
    if tla.nil?
      tla = Part.create(:project_id => self.id, :part_number => 0, :name => self.name, :parent_part_id => 0)
    end

    # Update Database from Onshape
    tla.update_onshape_assy(self,
      self[:onshape_top_document],
      self[:onshape_top_element],
      onshape_mainworkspace(self[:onshape_top_document]))
    end
  end

end
