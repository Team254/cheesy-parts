# Copyright 2012 Team 254. All Rights Reserved.
# @author pat@patfairbank.com (Patrick Fairbank)
#
# Represents a single part or assembly in a project.

class Part < Sequel::Model
  many_to_one :project
  many_to_one :parent_part, :class => self
  one_to_many :child_parts, :key => :parent_part_id, :class => self

  STATUS_MAP = { "designing" => "Design in progress",
                 "material" => "Material needs to be ordered",
                 "ordered" => "Waiting for materials",
                 "drawing" => "Needs drawing",
                 "ready" => "Ready to manufacture",
                 "manufacturing" => "Manufacturing in progress",
                 "coating" => "Waiting for coating",
                 "assembly" => "Waiting for assembly",
                 "done" => "Done" }
  PRIORITY_MAP = { 0 => "High", 1 => "Normal", 2 => "Low" }

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
    "#{project.part_number_prefix}-#{type == "assembly" ? "A" : "P"}-%04d" % part_number
  end
end
