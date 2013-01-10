<?php
if(!class_exists('ArtMapsTemplating')) {
require_once('Smarty/Smarty.class.php');
class ArtMapsTemplating {

    private function initSmarty($templateDir) {
        $smarty = new Smarty();
        $smarty->setTemplateDir($templateDir);
        $smarty->setCompileDir("$templateDir/.compilation");
        $smarty->setCacheDir("$templateDir/.cache");
        $smarty->setConfigDir("$templateDir/.configuration");
        return $smarty;
    }

    private function initSmartyForPlugin() {
        return $this->initSmarty(plugin_dir_path(__FILE__) . '../templates');
    }

    private function initSmartyForTheme() {
        return $this->initSmarty(get_stylesheet_directory() . '/templates');
    }

    public function renderNetworkAdminPage(
            $updated, $coreServerUrl, $masterKeyIsSet, $mapKey, $ipInfoDbKey) {
        $smarty = $this->initSmartyForPlugin();
        $smarty->setCaching(false);
        $smarty->assign('updated', $updated);
        $smarty->assign('coreServerUrl', $coreServerUrl);
        $smarty->assign('masterKeyIsSet', $masterKeyIsSet);
        $smarty->assign('mapKey', $mapKey);
        $smarty->assign('ipInfoDbKey', $ipInfoDbKey);
        return $smarty->fetch('network_admin_page.tpl');
    }

    public function renderBlogAdminPage(ArtMapsBlog $blog, $updated) {
        $smarty = $this->initSmartyForPlugin();
        $smarty->setCaching(false);
        $smarty->assign('updated', $updated);
        $smarty->assign('commentTemplate', $blog->getCommentTemplate());
        $smarty->assign('metadataTitleTemplate', $blog->getMetadataTitleTemplate());
        $smarty->assign('metadataFormatJS', $blog->getMetadataFormatJS());
        $smarty->assign('metadataTitleJS', $blog->getMetadataTitleJS());
        $smarty->assign('searchSource', $blog->getSearchSource());
        $smarty->assign('searchResultTitleJS', $blog->getSearchResultTitleJS());
        $smarty->assign('objectMetadataFormatJS', $blog->getObjectMetadataFormatJS());
        return $smarty->fetch('blog_admin_page.tpl');
    }

    public function renderImportAdminPage($imported) {
        $smarty = $this->initSmartyForPlugin();
        $smarty->setCaching(false);
        $smarty->assign('imported', $imported);
        return $smarty->fetch('import_admin_page.tpl');
    }

    public function renderUserProfileFields($externalBlog, $redirect) {
        $smarty = $this->initSmartyForPlugin();
        $smarty->setCaching(false);
        $smarty->assign('blog', $externalBlog);
        $smarty->assign('redirect', $redirect);
        return $smarty->fetch('user_profile_fields.tpl');
    }

    public function renderCommentTemplate(
            ArtMapsBlog $blog, $objectID, $link, $metadata) {
        $smarty = $this->initSmartyForTheme();
        $smarty->setCaching(true);
        $smarty->assign('objectID', $objectID);
        $smarty->assign('link', $link);
        $smarty->assign('metadata', $metadata);
        $tpl = $blog->getCommentTemplate();
        if($tpl != false && $tpl != '')
            return $smarty->fetch('string:' . $tpl, $objectID);
        return $smarty->fetch('comment_template.tpl', $objectID);
    }

    public function renderMetadataTitleTemplate(ArtMapsBlog $blog, $metadata) {
        $smarty = $this->initSmartyForTheme();
        $smarty->setCaching(false);
        $tpl = $blog->getMetadataTitleTemplate();
        $smarty->assign('metadata', $metadata);
        if($tpl != false && $tpl != '')
            return $smarty->fetch('string:' . $tpl);
        return $smarty->fetch('metadata_title_template.tpl');
    }

    public function renderMetadataTitleJS(ArtMapsBlog $blog) {
        $smarty = $this->initSmartyForTheme();
        $smarty->setCaching(false);
        $tpl = $blog->getMetadataTitleJS();
        if($tpl != false && $tpl != '')
            return $smarty->fetch('string:' . $tpl);
        return $smarty->fetch('metadata_title.tpl');
    }

    public function renderMetadataFormatJS(ArtMapsBlog $blog) {
        $smarty = $this->initSmartyForTheme();
        $smarty->setCaching(false);
        $tpl = $blog->getMetadataFormatJS();
        if($tpl != false && $tpl != '')
            return $smarty->fetch('string:' . $tpl);
        return $smarty->fetch('metadata_format.tpl');
    }

    public function renderSearchResultTitleJS(ArtMapsBlog $blog) {
        $smarty = $this->initSmartyForTheme();
        $smarty->setCaching(false);
        $tpl = $blog->getSearchResultTitleJS();
        if($tpl != false && $tpl != '')
            return $smarty->fetch('string:' . $tpl);
        return $smarty->fetch('search_result_title.tpl');
    }

    public function renderObjectMetadataFormatJS(ArtMapsBlog $blog) {
        $smarty = $this->initSmartyForTheme();
        $smarty->setCaching(false);
        $tpl = $blog->getObjectMetadataFormatJS();
        if($tpl != false && $tpl != '')
            return $smarty->fetch('string:' . $tpl);
        return $smarty->fetch('object_metadata_format.tpl');
    }
}}
?>