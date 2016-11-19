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
    if pn =~ /#{Regexp.quote(prefix)}-(P|A|p|a)-/
      return pn.sub(/#{Regexp.quote(prefix)}-(P|A|p|a)-/, '').to_i
    else
      return -1
    end
  end

  def update_onshape_assy(project, document, element, workspace, cp_part=true)
    # Save Onshape Tags
    self[:onshape_document]  = document
    self[:onshape_element]   = element
    self[:onshape_workspace] = workspace
    self[:onshape_mass] = 0

    # Crawl Assembly
    assy_def = onshape_request("/api/assemblies/d/"+document+"/w/"+workspace+"/e/"+element) rescue nil
    unless assy_def.nil?
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
          part.update_onshape_part(item, false)

        # If a CP Part
        else
          part.update_onshape_part(item)
        end
      end
    end

    # Update Mass and Flatten Non-CP Parts
    for part in self.child_parts
      self[:onshape_mass] += part[:onshape_mass] * part[:quantity] rescue nil
      part.destroy unless cp_part == true
    end

    self.save
  end

  def update_onshape_part(part_def, cp_part=true)
    self[:quantity] = self[:quantity].to_i + 1

    if self[:quantity] == 1

      # Update Part
      if part_def["type"] == 'Part'
        self[:onshape_document]  = part_def["documentId"]
        self[:onshape_element]   = part_def["elementId"]
        self[:onshape_workspace] = onshape_mainworkspace(part_def["documentId"])
        self[:onshape_part] = part_def["partId"]
        self[:onshape_microversion] = part_def["documentMicroversion"]

        # Update Material
        res = onshape_request("/api/parts/d/"+self[:onshape_document]+"/w/"+self[:onshape_workspace]+"/e/"+self[:onshape_element]+"/partid/"+self[:onshape_part]+"/metadata") rescue nil
        unless res.nil?
          self[:source_material] = res["material"]["id"] rescue nil
        end

        # Update Mass
        self.update_onshape_mass() if self[:source_material]
      
      # Update Assy
      else
        self.update_onshape_assy(project, part_def["documentId"], part_def["elementId"], onshape_mainworkspace(part_def["documentId"]), cp_part)
      end

    end
    self.save
  end

  def update_onshape_mass()
    res = onshape_request("/api/parts/d/"+self[:onshape_document]+"/w/"+self[:onshape_workspace]+"/e/"+self[:onshape_element]+"/partid/"+self[:onshape_part]+"/massproperties") rescue nil
    unless res.nil?
      self[:onshape_mass] = kg_to_lb(res["bodies"][self[:onshape_part]]["mass"][0].to_f) rescue nil
    end
  end

  def onshape_image
    # Use Thumbnail for Assembly
    if self.onshape_part.nil?
      onshape_request("/api/thumbnails/d/"+self.onshape_document+"/w/"+self.onshape_workspace+"/e/"+self.onshape_element+"/s/300x300", "", false) rescue nil

    # Generate Shaded View for Part
    else
      res = onshape_request("/api/parts/d/"+self.onshape_document+"/m/"+self.onshape_microversion+"/e/"+self.onshape_element+"/partid/"+self.onshape_part+"/shadedviews", "outputHeight=300&outputWidth=300&viewMatrix=1,1,0,0,-0.5,0.5,1,0,1,-1,1,0&pixelSize=0") rescue nil
      unless res.nil?
        Base64.decode64(res["images"][0])
      end
    end
  end

end
