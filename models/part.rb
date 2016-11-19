# Copyright 2012 Team 254. All Rights Reserved.
# @author pat@patfairbank.com (Patrick Fairbank)
#
# Represents a single part or assembly in a project.

class Part < Sequel::Model
  many_to_one :project
  many_to_one :parent_part, :class => self
  one_to_many :child_parts, :key => :parent_part_id, :class => self

  PART_TYPES = ["part", "assembly"]

  # The list of possible part statuses. Key: string stored in database, value: what is displayed to the user.
  STATUS_MAP = { "designing" => "Design in progress",
                 "material" => "Material needs to be ordered",
                 "ordered" => "Waiting for materials",
                 "drawing" => "Needs drawing",
                 "ready" => "Ready to manufacture",
                 "manufacturing" => "Manufacturing in progress",
                 "outsourced" => "Waiting for outsourced manufacturing",
                 "welding" => "Waiting for welding",
                 "scotchbrite" => "Waiting for Scotch-Brite",
                 "anodize" => "Ready for anodize",
                 "powder" => "Ready for powder coating",
                 "coating" => "Waiting for coating",
                 "assembly" => "Waiting for assembly",
                 "done" => "Done" }

  # Mapping of priority integer stored in database to what is displayed to the user.
  PRIORITY_MAP = { 0 => "High", 1 => "Normal", 2 => "Low" }

  # Assigns a part number based on the parent and type and returns a new Part object.
  def self.generate_number_and_create(project, type, parent_part)
    parent_part_id = parent_part.nil? ? 0 : parent_part.id
    parent_part_number = parent_part.nil? ? 0 : parent_part.part_number
    if type == "part"
      part_number = Part.filter(:project_id => project.id, :parent_part_id => parent_part_id, :type => "part")
                        .max(:part_number) || parent_part_number
      part_number += 1
    else
      part_number = Part.filter(:project_id => project.id, :type => "assembly").max(:part_number)  || -100
      part_number += 100
    end
    new(:part_number => part_number, :project_id => project.id, :type => type,
        :parent_part_id => parent_part.nil? ? 0 : parent_part.id)
  end

  def full_part_number
    "#{project.part_number_prefix}-#{type == "assembly" ? "A" : "P"}-%04d" % part_number unless part_number.nil?
  end

  def partname_to_number(pn)
    prefix = self.project[:part_number_prefix]
    pn.sub(/#{Regexp.quote(prefix)}-(P|A|p|a)-/, '').to_i   
  end

  def update_onshape_assy(project, document, element, workspace)
    # Save Onshape Tags
    self[:onshape_document]  = document
    self[:onshape_element]   = element
    self[:onshape_workspace] = workspace
    self.save

    # Crawl Assembly Definition
    assy_def = onshape_request("/api/assemblies/d/"+document+"/w/"+workspace+"/e/"+element)
    for item in assy_def["rootAssembly"]["instances"]

      # Lookup CP Parts
      partname = onshape_partname(item)
      part_number = partname_to_number(partname)
      part = Part[:part_number => part_number, :project_id => project[:id]]

      # If Not a CP Part
      if part.nil?
        part = Part[:onshape_element => item["elementId"], :onshape_part => item["partId"], :parent_part_id => self.id]
        if part.nil?
          part = Part.create(:project_id => project[:id], :name => partname, :parent_part_id => self.id, :type => "unassigned")
        end
      end

      part.update_onshape_part(item)
    end
  end

  def update_onshape_part(part_def)
    self[:quantity] = self[:quantity].to_i + 1

    if self[:quantity] == 1

      # Update Part
      if part_def["type"] == 'Part'
        self[:onshape_document]  = part_def["documentId"]
        self[:onshape_element]   = part_def["elementId"]
        self[:onshape_workspace] = onshape_mainworkspace(part_def["documentId"])
        self[:onshape_part] = part_def["partId"]
        self[:onshape_microversion] = part_def["documentMicroversion"]
      
      # Update Assy
      else
        self.update_onshape_assy(project, part_def["documentId"], part_def["elementId"], onshape_mainworkspace(part_def["documentId"]))
      end

    end
    self.save
  end

  def onshape_image
    if self.onshape_part.nil?
      res = onshape_request("/api/assemblies/d/"+self.onshape_document+"/w/"+self.onshape_workspace+"/e/"+self.onshape_element+"/shadedviews", "outputHeight=200&outputWidth=300&viewMatrix=0.612,0.612,0,0,-0.354,0.354,0.707,0,0.707,-0.707,0.707,0")
    else
      res = onshape_request("/api/parts/d/"+self.onshape_document+"/m/"+self.onshape_microversion+"/e/"+self.onshape_element+"/partid/"+self.onshape_part+"/shadedviews", "outputHeight=200&outputWidth=300&viewMatrix=0.612,0.612,0,0,-0.354,0.354,0.707,0,0.707,-0.707,0.707,0")
    end
    Base64.decode64(res["images"][0])
  end

end
