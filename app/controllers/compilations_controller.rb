class CompilationsController < ApplicationController
  include Drs::ControllerHelpers::EditableObjects

  before_filter :authenticate_user!, except: [:show, :show_download, :download]

  before_filter :can_edit?, only: [:edit, :update, :destroy, :add_entry, :delete_entry]
  before_filter :can_read?, only: [:show, :show_download, :download]

  load_resource
  before_filter :get_readable_entries, only: [:show]
  before_filter :remove_dead_entries, only: [:show, :show_download]
  before_filter :ensure_any_readable, only: [:show_download]

  def index
    @compilations = Compilation.users_compilations(current_user)
    @page_title = "My " + t('drs.compilations.name').capitalize + "s"
  end

  def new
    @compilation = Compilation.new
    @page_title = "New " + t('drs.compilations.name').capitalize
  end

  def create
    @compilation = Compilation.new(params[:compilation].merge(pid: mint_unique_pid))

    if !params[:entry_id].blank?
      @compilation.add_entry(params[:entry_id])
    end

    @compilation.depositor = current_user.nuid
    @compilation.mass_permissions = params[:mass_permissions]

    if params[:groups]
      @compilation = GroupPermissionsSetter.set_permissions(@compilation, params[:groups])
    end

    save_or_bust @compilation
    redirect_to @compilation
  end

  def edit
    @page_title = "Edit #{@compilation.title}"
  end

  def update
    @compilation.mass_permissions = params[:mass_permissions]

    if params[:groups]
      @compilation = GroupPermissionsSetter.set_permissions(@compilation, params[:groups])
    end

    if @compilation.update_attributes(params[:compilation])
      flash[:notice] = "#{t('drs.compilations.name').capitalize} successfully updated."
      redirect_to @compilation
    else
      flash.now.error = "#{t('drs.compilations.name').capitalize} failed to update."
    end
  end

  def show
    @page_title = "#{@compilation.title}"

    respond_to do |format|
      format.html{ render action: "show" }
      format.json{ render json: @compilation  }
    end
  end

  def destroy
    if @compilation.destroy
      flash[:notice] = "#{t('drs.compilations.name').capitalize} was successfully destroyed"
      redirect_to compilations_path
    else
      flash.now.error = "#{t('drs.compilations.name').capitalize} #{@compilation.title} was not successfully destroyed"
    end
  end

  def add_entry
    @compilation.add_entry(params[:entry_id])
    save_or_bust @compilation

    respond_to do |format|
      format.html { redirect_to @compilation }
      format.json { render :nothing => true }
      format.js   { render :nothing => true }
    end
  end

  def delete_entry
    @compilation.remove_entry(params[:entry_id])
    save_or_bust @compilation

    respond_to do |format|
      format.html { redirect_to @compilation }
      format.json { render :nothing => true }
      format.js   { render :nothing => true }
    end
  end

  def ping_download
    respond_to do |format|
      format.js do
        if File.file?(safe_zipfile_name)
          render("ping_download")
        else
          render :nothing => true
        end
      end
    end
  end

  def show_download
    Cerberus::Application::Queue.push(ZipCompilationJob.new(current_user, @compilation))
    @page_title = "Download #{@compilation.title}"
  end

  def download
    path_to_dl = Dir["#{Rails.root}/tmp/#{params[:id]}/*"].first
    send_file path_to_dl
  end

  private

  def get_readable_entries
    @entries = @compilation.entries.keep_if { |x| current_user_can? :read, x }
  end

  def ensure_any_readable
    entries = get_readable_entries
    error   = "You cannot download a set with no readable content"

    if entries.empty?
      flash[:error] = error
      redirect_to @compilation and return
    end

    content = []
    entries.each do |entry|
      content = content + entry.content_objects
    end

    content.keep_if { |c| c.klass != "ImageThumbnailFile" }

    unless (content.any? { |x| current_user_can? :read, x })
      flash[:error] = error
      redirect_to(@compilation) and return
    end
  end

  def remove_dead_entries
    dead_entries = @compilation.remove_dead_entries

    if dead_entries.length > 0
      flash.now[:error] = "The following items no longer exist in the repository and have been removed from your #{ t('drs.compilations.name') }: #{dead_entries.join(', ')}"
    end
  end

  def save_or_bust(compilation)
    if compilation.save!
      flash[:notice] = "#{t('drs.compilations.name').capitalize} successfully updated"
    else
      flash.now.error = "#{t('drs.compilations.name').capitalize} was not successfully updated"
    end
  end

  private

  def safe_zipfile_name
    safe_title = @compilation.title.gsub(/\s+/, "")
    safe_title = safe_title.gsub(":", "_")
    return "#{Rails.root}/tmp/#{@compilation.pid}/#{safe_title}.zip"
  end
end
